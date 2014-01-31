
unless defined?(Abaqus::System)

  require 'abaqus/node'
  require 'narray'

  class NVector
    def cross_product(other)
      unless self.shape == [3]
        raise DomainError
      end
      unless other.shape == [3]
        raise DomainError
      end
      NVector[ self[1]*other[2] - self[2]*other[1],
        self[2]*other[0] - self[0]*other[2],
        self[0]*other[1] - self[1]*other[0]]
    end
    def norm
      Math.sqrt(self * self)
    end
    def normalize
      self / self.norm
    end
    def normalize!
      n = self.norm
      self.size.times do |i|
        self[i] = self[i] / n
      end
      self
    end
  end

  module Abaqus
    class System
      extend Inp
      def self.parse(line, body)
        keyword, options = parse_command(line)
        unless keyword == "*SYSTEM"
          raise ArgumentError, "System.parse can trea *SYSTEM keyword only"
        end
        points = []
        line = parse_data(body) do |str|
          points << str
        end
        if points.size > 2
          raise ArgumentError,"Too much contents for *SYSTEM were given. Please check inp file"
        end
        a = points.join(',').split(/,/).map{|x| x.to_f}
        case a.size
        when 0
          #nothing  ==> reset
          Node.reset_converter
        when 3
          #shift
          Node.converter = create_shifter(*a)
        when 6
          #shift and rotate in z axis
          Node.converter = create_plain_rotater(*a)
        when 9
          #shift and rotate in 3d
          Node.converter = create_rotater

        else
          raise ArgumentError, "Incorrect contents for *SYSTEM were given. Please check inp file"
        end
        line
      end
      E1 = NVector[1.0, 0.0, 0.0]
      E2 = NVector[0.0, 1.0, 0.0]
      E3 = NVector[0.0, 0.0, 1.0]
      DELTA = 0.001
      def initialize(qmat)
        @qmat = qmat
      end
      def self.translate(vect)
        mat = NMatrix.float(4,4).I
        mat[3,0] = vect[0]
        mat[3,1] = vect[1]
        mat[3,2] = vect[2]
        return mat
      end
      def self.rotate(ax, ay, az)
        mat = NMatrix.float(4,4)
        mat[0,0..2] = ax.normalize
        mat[1,0..2] = ay.normalize
        mat[2,0..2] = az.normalize
        mat[3,3] = 1.0
        return mat
      end
      def self.create_shifter(dx,dy,dz)
        self.new(translate(NVector[dx,dy,dz]))
      end
      def self.create_plain_rotater(x0,y0,z0, x1, y1, z1)
        origin = NVector[x0,y0,z0]
        pos_x = NVector[x1,y1,z0]
        ax = pos_x - origin
        az = E3
        ay = az.cross_product(ax)
        self.new( translate(origin) * rotate(ax,ay,az))
      end
      def self.create_rotater(x0,y0,z0,x1,y1,z1,x2,y2,z2)
        origin = NVector[x0, y0, z0]
        pos_x  = NVector[x1,y1,z1]
        pos_z0  = NVector[x2,y2,z2]
        ax = pos_x - origin
        az0 = pos_z0 - origin
        az = ax.cross_product(az0)
        ay = az.cross_product(ax)
        self.new( translate(origin) * rotate(ax,ay,az) )
      end
      def convert(x,y,z)
        vec = NVector[x,y,z,1.0]
        res = @qmat * vec
        return res[0..2]
      end
    end
  end

end

if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestCrossProduct < Test::Unit::TestCase
    def setup
      @x = Abaqus::System::E1
      @y = Abaqus::System::E2
      @z = Abaqus::System::E3
    end
    def test_x
      res = @y.cross_product(@z)
      diff = (res - @x).norm
      assert(diff < 0.001)
    end
    def test_y
      res = @z.cross_product(@x)
      diff = (res - @y).norm
      assert(diff < 0.001)
    end
    def test_z
      res = @x.cross_product(@y)
      diff = (res - @z).norm
      assert(diff < 0.001)
    end
    def test_neg_x
      res = @z.cross_product(@y)
      diff = (@x + res).norm
      assert(diff < 0.001)
    end
    def test_neg_y
      res = @x.cross_product(@z)
      assert( (@y + res).norm < 0.001)
    end
    def test_neg_z
      res = @y.cross_product(@x)
      assert( (@z + res).norm < 0.001)
    end
  end
  class String
    def to_mock
      m = FlexMock.new("String#to_mock")
      arr = self.to_a
      arr << nil
      m.should_receive(:gets).at_most.times(arr.size).and_return(*arr)
      m
    end
  end
  class TestSystem < Test::Unit::TestCase
    def setup
      @x0, @y0, @z0 = 1.0, 2.0, 3.0
      @x1, @y1, @z1 = @x0, @y0+1.0, @z0+1.0
      @x2, @y2, @z2 = @x0 - 1.0, @y1, @z1
      @str1 = <<-NNN
      #{@x0}, #{@y0}, #{@z0}
      NNN
      @str2 = <<-NNN
      #{@x0}, #{@y0}, #{@z0}, #{@x1}, #{@y1}, #{@z1}
      NNN
      @str3 = <<-NNN
      #{@x0}, #{@y0}, #{@z0}, #{@x1}, #{@y1}, #{@z1}
      #{@x2}, #{@y2}, #{@z2}
      NNN
      @x = 4.0
      @y = 5.0
      @z = 6.0
      @node_str = <<-NNN
1, #{@x}, #{@y}, #{@z}
NNN
    end
    DELTA = 0.001
    def test_shift
      x = @x + @x0
      y = @y + @y0
      z = @z + @z0
      cmd = @str1+"*NODE\n"+@node_str
      n = nil
      assert_nothing_raised do
        m = cmd.to_mock
        line = Abaqus::System.parse("*SYSTEM",m)
        Abaqus::Node.parse(line,m)
        n = Abaqus::Node[1]
      end
      assert(n)
      assert_in_delta(x, n.x, DELTA)
      assert_in_delta(y, n.y, DELTA)
      assert_in_delta(z, n.z, DELTA)
    end
    def test_shift_converter
      x,y,z = 7, 8, 9
      xx,yy,zz = nil, nil, nil
      assert_nothing_raised do
        Abaqus::System.parse("*SYSTEM",@str1.to_mock)
        xx,yy,zz = * Abaqus::Node.convert(x,y,z)
      end
      assert_in_delta(x+@x0, xx, DELTA)
      assert_in_delta(y+@y0, yy, DELTA)
      assert_in_delta(z+@z0, zz, DELTA)
    end
    def test_translate
      x,y,z = 7, 8, 9
      mat = Abaqus::System::translate(NVector[@x0, @y0, @z0])
      conv = Abaqus::System.new(mat)
      xx,yy,zz = * conv.convert(x,y,z)
      assert_in_delta(x+@x0, xx, DELTA)
      assert_in_delta(y+@y0, yy, DELTA)
      assert_in_delta(z+@z0, zz, DELTA)
    end
    def test_rotate_180_in_z
      vx = NVector[-1,0,0]
      vy = NVector[0,-1,0]
      vz = NVector[0,0, 1]
      mat = Abaqus::System::rotate(vx, vy, vz)
      conv = Abaqus::System.new(mat)
      x,y,z = * conv.convert(@x,@y,@z)
      assert_in_delta(-@x, x, DELTA)
      assert_in_delta(-@y, y, DELTA)
      assert_in_delta( @z, z, DELTA)
    end
    def test_rotate_180_in_z_and_shift
      vx = NVector[-1,0,0]
      vy = NVector[0,-1,0]
      vz = NVector[0,0, 1]
      rot = Abaqus::System::rotate(vx, vy, vz)
      trans = Abaqus::System::translate(NVector[@x0,@y0,@z0])
      mat = trans * rot
      conv = Abaqus::System.new(mat)
      x,y,z = * conv.convert(@x,@y,@z)
      assert_in_delta(-@x+@x0, x, DELTA)
      assert_in_delta(-@y+@y0, y, DELTA)
      assert_in_delta( @z+@z0, z, DELTA)
    end
    def test_create_plain_rotater
      conv = Abaqus::System::create_plain_rotater(@x0,     @y0, @z0,
                                                  @x0-1.0, @y0, @z1)
      x,y,z = * conv.convert(@x,@y,@z)
      assert_in_delta( @z+@z0, z, DELTA)
      assert_in_delta(-@y+@y0, y, DELTA)
      assert_in_delta(-@x+@x0, x, DELTA)
    end
    def test_rotate_by_create_plain_rotater
      conv = Abaqus::System::create_plain_rotater(0.0, 0.0, 0.0,
                                                  -1.0, 0.0, 0.0)
      x,y,z = * conv.convert(@x,@y,@z)
      assert_in_delta(-@x, x, DELTA)
      assert_in_delta(-@y, y, DELTA)
      assert_in_delta( @z, z, DELTA)
    end
    def test_rotate_by_create_plain_rotater_2
      conv = Abaqus::System::create_plain_rotater(0.0, 0.0, 0.0,
                                                  -1.0, 0.0, 1.0)
      x,y,z = * conv.convert(@x,@y,@z)
      assert_in_delta(-@x, x, DELTA)
      assert_in_delta(-@y, y, DELTA)
      assert_in_delta( @z, z, DELTA)
    end
    def test_rotate_by_create_plain_rotater_3
      conv = Abaqus::System::create_plain_rotater(1.0, 0.0, 0.0,
                                                  -0.0, 0.0, 1.0)
      x,y,z = * conv.convert(@x,@y,@z)
      assert_in_delta( @z, z, DELTA)
      assert_in_delta(-@y, y, DELTA)
      assert_in_delta(1-@x, x, DELTA)
    end
    def test_rotate_by_create_plain_rotater_4
      conv = Abaqus::System::create_plain_rotater(1.0, 1.0, 0.0,
                                                  -0.0, 1.0, 1.0)
      x,y,z = * conv.convert(@x,@y,@z)
      assert_in_delta( @z, z, DELTA)
      assert_in_delta(1-@y, y, DELTA)
      assert_in_delta(1-@x, x, DELTA)
    end
    def test_rotate_by_create_plain_rotater_5
      conv = Abaqus::System::create_plain_rotater(1.0, 1.0, 2.0,
                                                  -0.0, 1.0, 1.0)
      x,y,z = * conv.convert(@x,@y,@z)
      assert_in_delta(2+@z, z, DELTA)
      assert_in_delta(1-@y, y, DELTA)
      assert_in_delta(1-@x, x, DELTA)
    end

  end
  class TestNorm < Test::Unit::TestCase
    def setup
      @v = NVector[1.0,2.0, 3.0]
    end
    def test_norm_1
      assert_equal(1.0, NVector[1.0,0.0,0.0].norm)
    end
    def test_norm_x_2
      assert_in_delta(2,0, NVector[2.0,0.0, 0.0].norm, 0.001)
    end
    def test_norm_3
      ans = Math.sqrt(1.0 + 2.0*2.0 + 3.0*3.0)
      assert_in_delta(ans, @v.norm, 0.001)
    end
    def test_normalize
      nv = @v.normalize
      assert_in_delta(1.0, nv.norm, 0.001)
    end
    def test_normalize!
      @v.normalize!
      assert_in_delta(1.0, @v.norm, 0.001)
    end
  end
end

