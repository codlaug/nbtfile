require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'nbtfile/region'
require 'fileutils'

describe NBTFile::RegionFile do
  before :each do
    @temp_dir = 'tmp_regions'
    FileUtils.mkdir_p(@temp_dir)
    @region_filename = File.join(@temp_dir, 'region.mcr')
    @region_file = NBTFile::RegionFile.new(@region_filename)
  end

  after :each do
    FileUtils.rm_rf(@temp_dir)
  end

  it 'does not immediately create an empty file' do
    expect(File.exist?(@region_filename)).to be_falsey
  end

  it 'returns nil for non-existent chunks' do
    expect(@region_file.get_chunk(0, 0)).to be_nil
  end

  it 'idempotently deletes chunks' do
    @region_file.delete_chunk(0, 0)
  end

  it 'stores data in chunks' do
    content = 'foobar'
    @region_file.store_chunk(0, 0, content)
    expect(@region_file.get_chunk(0, 0)).to eq(content)
  end

  it 'stores data in chunks in any supported format' do
    content = 'foobar'
    NBTFile::RegionFile::Private::COMPRESSIONS.each { |_k, compression|
      @region_file.store_chunk(0, 0, content, compression)
      expect(@region_file.get_chunk(0, 0)).to eq(content)
    }
  end

  it 'raises a runtime error on invalid compression type' do
    content = 'foobar'
    expect { @region_file.store_chunk(0, 0, content, -1) }.to raise_error(error = NotImplementedError)
  end

  it 'creates the file after a chunk has been stored' do
    content = 'foobar'
    @region_file.store_chunk(0, 0, content)
    expect(File.exist?(@region_filename)).to be_truthy
  end

  it 'removes the file only after the last chunk is deleted' do
    content = 'foobar'
    @region_file.store_chunk(0, 0, content)
    @region_file.store_chunk(1, 0, content)
    @region_file.delete_chunk(0, 0)
    expect(File.exist?(@region_filename)).to be_truthy
    @region_file.delete_chunk(1, 0)
    expect(File.exist?(@region_filename)).to be_falsey
  end

  it 'persists data in the file' do
    content = 'foobar'
    @region_file.store_chunk(0, 0, content)
    region_file2 = NBTFile::RegionFile.new(@region_filename)
    expect(region_file2.get_chunk(0, 0)).to eq(content)
  end

  it 'recognizes the number of chunks stored' do
    content = 'foobar'
    @region_file.store_chunk(0, 0, content)
    region_file2 = NBTFile::RegionFile.new(@region_filename)
    region_file2.store_chunk(1, 0, content)
    region_file2.delete_chunk(1, 0)
    expect(File.exist?(@region_filename)).to be_truthy
    region_file2.delete_chunk(0, 0)
    expect(File.exist?(@region_filename)).to be_falsey
  end

  it 'can enumerate stored chunks' do
    content = 'foobar'
    @region_file.store_chunk(0, 0, content)
    @region_file.store_chunk(1, 0, content)
    @region_file.store_chunk(0, 2, content)
    expect(Set.new(@region_file.live_chunks)).to eq(Set[[0, 0], [1, 0], [0, 2]])
  end
end

describe NBTFile::RegionManager do
  before :each do
    @temp_dir = 'tmp_regions'
    FileUtils.mkdir_p(@temp_dir)
    @region_manager = NBTFile::RegionManager.new(@temp_dir)
  end

  after :each do
    FileUtils.rm_rf(@temp_dir)
  end

  it 'should allow storing and retrieving chunks' do
    content = 'foobar'
    @region_manager.store_chunk(0, 0, content) # , NBTFile::RegionFile::Private::DEFLATE_COMPRESSION)
    expect(@region_manager.get_chunk(0, 0)).to eq(content)
  end

  it 'creates appropriate region files' do
    content = 'foobar'
    @region_manager.store_chunk(0, 0, content)
    expect(File.exist?(File.join(@temp_dir, 'r.0.0.mcr'))).to be_truthy
    @region_manager.store_chunk(32, 32, content)
    expect(File.exist?(File.join(@temp_dir, 'r.1.1.mcr'))).to be_truthy
    @region_manager.store_chunk(-16, 64, content)
    @region_manager.store_chunk(-32, 64, content)
    expect(File.exist?(File.join(@temp_dir, 'r.-1.2.mcr'))).to be_truthy
    expect(File.exist?(File.join(@temp_dir, 'r.-2.2.mcr'))).to be_falsey
  end

  it 'deletes chunks (idempotently)' do
    content = 'foobar'
    @region_manager.store_chunk(0, 0, content)
    @region_manager.delete_chunk(0, 0)
    expect(File.exist?(File.join(@temp_dir, 'r.0.0.mcr'))).to be_falsey
    @region_manager.delete_chunk(0, 0)
  end
end
