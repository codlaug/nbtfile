shared_examples_for 'high-level types' do
  it 'should include NBTFile::Types::Base' do
    expect(@type).to be < NBTFile::Types::Base
  end
end

INTEGER_TYPE_CASES = {
  NBTFile::Types::Byte => 8,
  NBTFile::Types::Short => 16,
  NBTFile::Types::Int => 32,
  NBTFile::Types::Long => 64
}

INTEGER_TYPE_CASES.each do |type, bits|
  range = (-2**(bits - 1))..(2**(bits - 1) - 1)
  describe "#{type}" do
    it_should_behave_like 'high-level types'

    before :all do
      @type = type
    end

    it "should reject values larger than #{range.end}" do
      expect(-> { type.new(range.end + 1) }).to raise_error(RangeError)
    end

    it "should reject values smaller than #{range.begin}" do
      expect(-> { type.new(range.begin - 1) }).to raise_error(RangeError)
    end

    it 'should accept integers' do
      type.new(1)
    end

    it 'should have a value attribute' do
      expect(type.new(42).value).to eq(42)
    end

    it 'should reject non-integers' do
      expect(-> { type.new(0.5) }).to raise_error(TypeError)
    end

    it 'should support #to_int' do
      expect(type.new(3).to_int).to eq(3)
    end

    it 'should support #to_i' do
      expect(type.new(3).to_i).to eq(3)
    end

    it 'should support equality by value' do
      expect(type.new(3)).to eq(3)
      expect(type.new(3)).to_not eq(4)
      expect(type.new(3)).to eq(type.new(3))
      expect(type.new(3)).to_not eq(type.new(4))
    end
  end
end

shared_examples_for 'floating-point high-level types' do
  it 'should accept Numerics' do
    @type.new(3.3)
    @type.new(3)
    @type.new(2**68)
  end

  it 'should not accept non-numerics' do
    expect(-> { @type.new('3.3') }).to raise_error(TypeError)
  end

  it 'should have a value attribute' do
    expect(@type.new(3.3).value).to eq(3.3)
  end

  it 'should support #to_f' do
    expect(@type.new(3.3).to_f).to eq(3.3)
  end

  it 'should support equality by value' do
    expect(@type.new(3.3)).to eq(3.3)
    expect(@type.new(3.3)).to_not eq(4)
    expect(@type.new(3.3)).to eq(@type.new(3.3))
    expect(@type.new(3.3)).to_not eq(@type.new(4))
  end
end

describe NBTFile::Types::Float do
  it_should_behave_like 'high-level types'
  it_should_behave_like 'floating-point high-level types'

  before :all do
    @type = NBTFile::Types::Float
  end
end

describe NBTFile::Types::Double do
  it_should_behave_like 'high-level types'
  it_should_behave_like 'floating-point high-level types'

  before :all do
    @type = NBTFile::Types::Double
  end
end

describe NBTFile::Types::String do
  it_should_behave_like 'high-level types'

  before :all do
    @type = NBTFile::Types::String
  end

  it 'should have a #value accessor' do
    expect(NBTFile::Types::String.new('foo').value).to eq('foo')
  end

  it 'should support #to_s' do
    expect(NBTFile::Types::String.new('foo').to_s).to eq('foo')
  end
end

describe NBTFile::Types::ByteArray do
  it_should_behave_like 'high-level types'

  before :all do
    @type = NBTFile::Types::ByteArray
  end

  it 'should have a #value accessor' do
    expect(NBTFile::Types::ByteArray.new('foo').value).to eq('foo')
  end
end

describe NBTFile::Types::List do
  it_should_behave_like 'high-level types'

  before :all do
    @type = NBTFile::Types::List
  end

  before :each do
    @instance = NBTFile::Types::List.new(NBTFile::Types::Int)
  end

  it 'should accept instances of the given type' do
    @instance << NBTFile::Types::Int.new(3)
    expect(@instance.length).to eq(1)
  end

  it 'should reject instances of other types' do
    expect(lambda do
      @instance << NBTFile::Types::Byte.new(3)
    end).to raise_error(TypeError)
    expect(lambda do
      @instance << 3
    end).to raise_error(TypeError)
    expect(lambda do
      @instance << nil
    end).to raise_error(TypeError)
    expect(@instance.length).to eq(0)
  end

  it 'should implement Enumerable' do
    expect(NBTFile::Types::List).to be < Enumerable
  end
end

describe NBTFile::Types::Compound do
  it_should_behave_like 'high-level types'

  before :all do
    @type = NBTFile::Types::Compound
  end

  before :each do
    @instance = NBTFile::Types::Compound.new
  end

  it 'should allow setting and retrieving a field' do
    @instance['foo'] = NBTFile::Types::Int.new(3)
    expect(@instance['foo']).to eq(NBTFile::Types::Int.new(3))
  end

  it 'should allow removing a field' do
    @instance['foo'] = NBTFile::Types::Int.new(3)
    @instance.delete 'foo'
    @instance.delete 'foo'
    expect(@instance['foo']).to be_nil
  end

  it 'should accept values deriving from NBTFile::Types::Base' do
    @instance['foo'] = NBTFile::Types::Int.new(3)
  end

  it 'should reject values not deriving from NBTFile::Types::Base' do
    expect(-> { @instance['foo'] = 3 }).to raise_error(TypeError)
  end
end

describe NBTFile::Types::IntArray do
  it_should_behave_like 'high-level types'

  before :all do
    @type = NBTFile::Types::IntArray
  end

  it 'should have a #values accessor' do
    expect(NBTFile::Types::IntArray.new([1, 2]).values).to eq([Types::Int.new(1), Types::Int.new(2)])
  end
end
