# nbtfile/region
#
# Copyright (c) 2011 MenTaLguY
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'set'

module NBTFile
  class RegionFile
    attr_reader :file_size
    module Private #:nodoc:
      extend self

      REGION_WIDTH_IN_CHUNKS = 32
      SECTOR_SIZE = 4096
      TABLE_ENTRY_SIZE = 4
      TABLE_SIZE = REGION_WIDTH_IN_CHUNKS * REGION_WIDTH_IN_CHUNKS *
                   TABLE_ENTRY_SIZE
      TIMESTAMP_TABLE_OFFSET = TABLE_SIZE
      DATA_START_OFFSET = TABLE_SIZE * 2
      DATA_START_SECTOR = DATA_START_OFFSET / SECTOR_SIZE

      COMPRESSIONS = { NO_COMPRESSION: 0,
                       GZIP_COMPRESSION: 1,
                       DEFLATE_COMPRESSION: 2,
                       LZ4_COMPRESSION: 255 }

      ACTUAL_COMPRESSIONS = COMPRESSIONS.reject { |k, _v| k == :NO_COMPRESSION }

      def length_in_sectors(length)
        (length + (SECTOR_SIZE - 1)) / SECTOR_SIZE
      end

      def chunk_to_file_offset(x, z)
        TABLE_ENTRY_SIZE * (x * REGION_WIDTH_IN_CHUNKS + z)
      end

      def table_index_to_chunk(index)
        [index / REGION_WIDTH_IN_CHUNKS,
         index % REGION_WIDTH_IN_CHUNKS]
      end

      def read_alloc_table_entry(io, x, z)
        io.seek(chunk_to_file_offset(x, z))
        (info,) = io.read(TABLE_ENTRY_SIZE).unpack('N')
        return nil unless info
        address = (info >> 8)
        return nil if address.zero?
        length = (info & 0xff)
        [address, length]
      end

      def read_sectors(io, address, length)
        io.seek(address * SECTOR_SIZE)
        io.read(length * SECTOR_SIZE)
      end

      def write_offset_table_entry(io, x, z, address, length)
        io.seek(chunk_to_file_offset(x, z))
        info = (address << 8 | length)
        io.write([info].pack('N'))
      end

      def update_chunk_timestamp(io, x, z)
        io.seek(TIMESTAMP_TABLE_OFFSET + chunk_to_file_offset(x, z))
        io.write([Time.now.to_i].pack('N'))
      end

      def write_sectors(io, address, data)
        io.seek(address * SECTOR_SIZE)
        io.write(data)
      end
    end

    def initialize(filename)
      @filename = filename
      @high_water_mark = Private::DATA_START_SECTOR
      @live_chunks = Set.new
      @file_size = if File.file?(filename) && File.size?(filename)
                     File.size(filename)
                   else
                     0
                   end

      begin
        File.open(@filename, 'rb') do |stream|
          table = stream.read(Private::TABLE_SIZE)
          infos = table.unpack('N*')
          infos.each_with_index do |info, index|
            if info.nonzero?
              x, z = Private.table_index_to_chunk(index)
              @live_chunks.add [x, z]
            end
          end
        end
      rescue Errno::ENOENT
      end
    end

    def live_chunks
      @live_chunks.dup
    end

    def get_chunk(x, z)
      File.open(@filename, 'rb') do |stream|
        address, length = Private.read_alloc_table_entry(stream, x, z)
        return nil unless address
        raw_data = Private.read_sectors(stream, address, length)
        payload_length, payload = raw_data.unpack('Na*')
        case
        when payload.length < payload_length
          fail "Chunk length #{payload_length} greater than "
          "allocated length #{payload.length}"
        when payload.length > payload_length
          payload = payload[0, payload_length]
        end
        compression_type, compressed_data = payload.unpack('Ca*')
        unless Private::COMPRESSIONS.values.include?(compression_type)
          fail "Unsupported compression type #{compression_type}"
        end
        case compression_type
        when Private::COMPRESSIONS[:NO_COMPRESSION]
          compressed_data
        when Private::COMPRESSIONS[:GZIP_COMPRESSION]
          io = StringIO.new(compressed_data, 'rb')
          Zlib::GzipReader.new(io).read
        when Private::COMPRESSIONS[:DEFLATE_COMPRESSION]
          Zlib::Inflate.inflate(compressed_data)
        when Private::COMPRESSIONS[:LZ4_COMPRESSION]
          LZ4.decompress(compressed_data)
        else
          fail NotImplementedError, "Compression type #{compression_type} is not yet implemented"
        end
      end
    rescue Errno::ENOENT
      nil
    end

    def store_chunk(x, z, content, compression = Private::COMPRESSIONS[:DEFLATE_COMPRESSION])
      @live_chunks.add [x, z]
      File.open(@filename, 'w+b') do |stream|
        compressed_data = case compression
                          when Private::COMPRESSIONS[:NO_COMPRESSION]
                            content
                          when Private::COMPRESSIONS[:LZ4_COMPRESSION]
                            LZ4.compress(content)
                          when Private::COMPRESSIONS[:GZIP_COMPRESSION]
                            wio = StringIO.new('w')
                            w_gz = Zlib::GzipWriter.new(wio)
                            w_gz.write(content)
                            w_gz.close
                            wio.string
                          when Private::COMPRESSIONS[:DEFLATE_COMPRESSION]
                            Zlib::Deflate.deflate(content, Zlib::DEFAULT_COMPRESSION)
                          else
                            fail NotImplementedError, "Compression type #{compression} is not yet implemented"
                          end

        payload_length = compressed_data.length + 1
        payload = [payload_length, compression,
                   compressed_data].pack('NCa*')
        length = Private.length_in_sectors(payload.length)
        address = @high_water_mark
        @high_water_mark += length
        Private.write_sectors(stream, address, payload)
        Private.write_offset_table_entry(stream, x, z, address, length)
        Private.update_chunk_timestamp(stream, x, z)
      end
      self
    end

    def delete_chunk(x, z)
      @live_chunks.delete [x, z]
      if @live_chunks.empty?
        begin
          File.unlink(@filename)
        rescue Errno::ENOENT
        end
      else
        File.open(@filename, 'w+b') do |stream|
          Private.write_offset_table_entry(stream, x, z, 0, 0)
          Private.update_chunk_timestamp(stream, x, z)
        end
      end
      self
    end
  end

  class RegionManager
    def regions
      Dir.glob(@region_dir + '*.mca').collect do |file|
        RegionFile.new(File.join(@region_dir, file))
      end
    end

    module Private #:nodoc: all
      extend self

      REGION_WIDTH_IN_CHUNKS = RegionFile::Private::REGION_WIDTH_IN_CHUNKS

      def get_region_coords_for_chunk(x, z)
        r_x = x.to_i / REGION_WIDTH_IN_CHUNKS
        r_z = z.to_i / REGION_WIDTH_IN_CHUNKS
        [r_x, r_z]
      end

      def get_local_chunk_coords(x, z)
        c_x = x.to_i % REGION_WIDTH_IN_CHUNKS
        c_z = z.to_i % REGION_WIDTH_IN_CHUNKS
        [c_x, c_z]
      end

      def get_region_filename_for_chunk(x, z)
        r_x, r_z = get_region_coords_for_chunk(x, z)
        "r.#{r_x}.#{r_z}.mcr"
      end
    end

    def initialize(region_dir)
      @region_dir = region_dir
    end

    def get_region_for_chunk(x, z)
      filename = Private.get_region_filename_for_chunk(x, z)
      RegionFile.new(File.join(@region_dir, filename))
    end

    def store_chunk(x, z, content, compression = RegionFile::Private::COMPRESSIONS[:DEFLATE_COMPRESSION])
      region_file = get_region_for_chunk(x, z)
      c_x, c_z = Private.get_local_chunk_coords(x, z)
      region_file.store_chunk(c_x, c_z, content, compression)
      self
    end

    def get_chunk(x, z)
      region_file = get_region_for_chunk(x, z)
      c_x, c_z = Private.get_local_chunk_coords(x, z)
      region_file.get_chunk(c_x, c_z)
    end

    def delete_chunk(x, z)
      region_file = get_region_for_chunk(x, z)
      c_x, c_z = Private.get_local_chunk_coords(x, z)
      region_file.delete_chunk(c_x, c_z)
      self
    end
  end
end
