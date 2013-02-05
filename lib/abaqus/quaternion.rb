
unless defined?(ABAQUS_QUATERNION_RB)
  ABAQUS_QUATERNION_RB = true

  require 'narray'

  module Abaqus

    class Vector
      def initialize(x = 0.0, y = 0.0, z=0.0)
        case x
        when Vector
          @data = x.data
        when Quaternion
          @data = x.data.clone
          @data[3] = 0.0
        when NArray
          if(x.size > 3)
            @data = x[0..3]
          else
            @data = NArray.float(4)
            @data[0..(x.size)] = x[]
          end
        when Numeric
          @data = NArray[x.to_f, y, z, 0.0]
        end
      end
      def x() @data[0] end
      def y() @data[1] end
      def z() @data[2] end
      attr :data
      def x=(v) @data[0] = v end
      def y=(v) @data[1] = v end
      def z=(v) @data[2] = v end
      def self.[](*arr)
        return Vector.new(*arr)
      end
      def [](i) @data[i] end
      def []=(i, v) @data[i] = v end
      def v() return VVector.new(data) end
      def h() return HVector.new(data) end
      def to_q() return Quaternion.new(data) end
      def +(o)
        case o
        when Vector
          return Vector.new(data+o.data)
        when Numeric
          return Vector.new(data+o)
        else
          raise ArgumentError
        end
      end
      def -(o)
        case o
        when Vector
          return Vector.new(data-o.data)
        when Numeric
          return Vector.new(data-o)
        else
          raise ArgumentError
        end
      end
      def *(o)
        case o
        when Numeric
          return Vector.new(data*o)
        else
          raise ArgumentError
        end
      end
      def /(o)
        case o
        when Numeric
          return Vector.new(data/o)
        else
          raise ArgumentError
        end
      end
      def to_translation_matrix
        mat = Matrix.I
        mat[3,0] = x
        mat[3,1] = y
        mat[3,2] = z
      end
    end

    ######################################################################
    class HVector < Vector
      def initalize(*arg)
        super
      end

      def +(o)
        case o
        when Numeric
          return HVector.new(data+o)
        when HVector
          return HVector.new(data+o.data)
        else
          raise ArgumentError
        end
      end
      def -(o)
        case o
        when Numeric
          return HVector.new(data-o)
        when HVector
          return HVector.new(data-o.data)
        else
          raise ArgumentError
        end
      end
      def *(o)
        case o
        when Vector, Quaternion
          # inner_product
          return (data*o.data).sum
        when NArray
          return (data*o).sum
        when Numeric
          return HVector.new(data*o)
        end
      end
    end

    ######################################################################
    class VVector < Vector
      def initalize(*arg)
        super
      end

      def +(o)
        case o
        when Numeric
          return VVector.new(data+o)
        when HVector
          raise ArgumentError
        when VVector, Vector
          return VVector.new(data+o.data)
        else
          raise ArgumentError
        end
      end
      def -(o)
        case o
        when Numeric
          return VVector.new(data-o)
        when HVector
          raise ArgumentError
        when VVector
          return VVector.new(data-o.data)
        else
          raise ArgumentError
        end
      end
      def *(o)
        case o
        when HVector
          mat = NArray.float(4,4)
          4.times do |i|
            mat[true,i] = data[i] * o.data
          end
          return Matrix.new(mat)
        when VVector
          # inner_product
          return (data*o.data).sum
        when Quaternion
          return self.to_q * o
        when Matrix
          res = NArray.float(4)
        when Numeric
          return HVector.new(data*o)
        end
      end
    end

    class Matrix
      def initialize(x=0.0)
        case x
        when NArray
          case x.rank
          when 1
            raise NotImplimentedError unless x.size == 4
            @data = NArray.float(4,4)
            4.times do |i|
              @data[i,i] = x[i]
            end
          when 2
            raise ArgumentError unless x.shape == [4,4]
            @data = x
          else
            raise ArgumentError
          end
        when Numeric
          @data = NArray.float(4,4)
          @data += x unless x == 0.0
        end
      end
      attr :data
      I =  self.new(NArray[1.0, 1.0, 1.0, 1.0]).freeze
      def *(o)
        case o
        when Matrix
          res = NArray.float(4,4)
          4.times do |row|
            4.times do |col|
              res[col, row] = data[ture, row].mul_sum(o.data[col, true],1)
            end
          end
          return Matrix.new(res)
        when VVector
          res = NArray.float(4)
          4.times do |row|
            res[row] = data[true, row].mul_sum(o.data,1)
          end
          return VVector.new(res)
        when HVector
          res = NArray.float(4,4)
          4.times do |col|
            res[col, true] = data[col, true] * o.data[col]
          end
          return Matrix.new(res)
        when Numeric
          return Matrix.new(data * o)
        else
          raise ArgumentError
        end
      end
      def +(o)
        case o
        when Matrix
          return Matrix.new(data + o.data)
        when Numeric
          return Matrix.new(data + o)
        else
          raise ArgumentError
        end
      end
      def -(o)
        case o
        when Matrix
          return Matrix.new(data - o.data)
        when Numeric
          return Matrix.new(data - o)
        else
          raise ArgumentError
        end
      end
      def /(o)
        case o
        when Matrix, VVector, HVector, Vector
          raise NotImplimentedError
        when Numeric
          return NMatrix(data / o)
        else
          raise ArgumentErro
        end
      end
    end


    class Quaternion
      def initialize(x = 0.0, y=0.0, z=0.0, r=0.0)
        case x
        when Quaternion, Vector
          @data = x.data.dup
        when NArray
          raise ArgumentError unless x.shape == [4]
          @data = x
        when Numeric
          @data = NArray[x.to_f,y,z,r]
        else
          raise ArgumentError
        end
      end
      def x () @data[0] end
      def y () @data[1] end
      def z () @data[2] end
      def r () @data[3] end
      attr :data
      alias :i :x
      alias :j :y
      alias :k :z

      # operators
      #
      %w(+ -).each do |op|
        self.class_eval <<-NNN
        def #{op}(o)
          case o
          when Numeric, NArray
            return Quaternion.new(@data #{op} o)
          when Quaternion
            return Quaternion.new(@data #{op} o.data)
          else
            raise ArgumentError
          end
        end
        NNN
      end

      def *(o)
        case o
        when Quaternion
          xx = r * o.x + x * o.r + y * o.z - z * o.y
          yy = r * o.y - x * o.z + y * o.r + z * o.x
          zz = r * o.z + x * o.y - y * o.x + z * o.r
          rr = r * o.r - x * o.x - y * o.y - z * o.z
          return Quaternion.new(xx, yy, zz, rr)
        when Numeric
          return Quaternion.new(data*o)
        when Vector
          vv = HVector.new(data)
          hv = VVector.new(o.data)
          return vv * hv
        else
          raise ArgumentError
        end
      end
      def /(o)
        case o
        when Numeric, NArray
          return Quaternion.new(data/o)
        when Quaternion
          return self * o.inv
        else
          raise ArgumentError
        end
      end
      def conj
        Quaternion.new(-x, -y, -z, r)
      end

      def abs
        (@data ** 2.0).sum
      end

      def inv
        conj / (@data ** 2).sum
      end

      def h
        return HVector.new(self)
      end
      def v
        return VVector.new(self)
      end
      def to_v
        return Vector.new(self)
      end
      def as_v
        return Vector.new(@data)
      end

      def self.RotationInDegree(rot, dx, dy, dz)
        rad = rot * Math::PI / 180.0
        return RotationInRadian(rad, dx, dy, dz)
      end
      def self.RotationInRadian(rot, dx, dy, dz)
        r = rot / 2.0
        c = Math.cos(r)
        s = Math.sin(r)
        return Quaternion.new(s*dx, s*dy, s*dz, c)
      end
    end
  end

end

if $0 == __FILE__
  require 'test/unit'

  module Abaqus
    DELTA = 1.0E-10
    class TestVVector < Test::Unit::TestCase

      def test_construct
        v = VVector.new
        assert_in_delta(0.0, v.x, DELTA)
        assert_in_delta(0.0, v.y, DELTA)
        assert_in_delta(0.0, v.z, DELTA)
        w = VVector.new(1)
        assert_in_delta(1.0, w.x, DELTA)
        assert_in_delta(0.0, w.y, DELTA)
        assert_in_delta(0.0, w.z, DELTA)
        u = VVector.new(1, 2, 3.0)
        assert_in_delta(1.0, u.x, DELTA)
        assert_in_delta(2.0, u.y, DELTA)
        assert_in_delta(3.0, u.z, DELTA)
      end
      def test_add_scalar
        u = VVector.new(1, 2, 3)
        v = u + 2
        assert_in_delta(3.0, v.x, DELTA)
        assert_in_delta(4.0, v.y, DELTA)
        assert_in_delta(5.0, v.z, DELTA)
      end
      def test_add_vvector
        u = VVector.new(1,2,3)
        w = VVector.new(4,5,6)
        v = u + w
        assert_in_delta(5.0, v.x, DELTA)
        assert_in_delta(7.0, v.y, DELTA)
        assert_in_delta(9.0, v.z, DELTA)
      end

      def test_subtract_scalar
        u = VVector.new(1,2,3)
        v = u - 2
        assert_in_delta(-1.0, v.x, DELTA)
        assert_in_delta(0.0, v.y, DELTA)
        assert_in_delta(1.0, v.z, DELTA)
      end
      def test_multiply_vvector
        u = VVector.new(1,2,3)
        v = VVector.new(4,5,6)
        r = u * v
        ans = (1*4+2*5+3*6).to_f
        assert_kind_of(Numeric, r)
        assert_in_delta(ans, r, DELTA)
      end
      def test_multiply_hvector
        v = VVector.new(1,2,3)
        u = HVector.new(4,5,6)
        r = v * u
        assert_kind_of(Matrix, r)
        3.times do |row|
          3.times do |col|
            assert_in_delta(v.data[row]*u.data[col], r.data[col,row], DELTA)
          end
        end
      end
    end

    class TestHVector < Test::Unit::TestCase

      def test_construct
        v = HVector.new
        assert_in_delta(0.0, v.x, DELTA)
        assert_in_delta(0.0, v.y, DELTA)
        assert_in_delta(0.0, v.z, DELTA)
        w = HVector.new(1)
        assert_in_delta(1.0, w.x, DELTA)
        assert_in_delta(0.0, w.y, DELTA)
        assert_in_delta(0.0, w.z, DELTA)
        u = HVector.new(1, 2, 3.0)
        assert_in_delta(1.0, u.x, DELTA)
        assert_in_delta(2.0, u.y, DELTA)
        assert_in_delta(3.0, u.z, DELTA)
      end
      def test_add_scalar
        u = HVector.new(1, 2, 3)
        v = u + 2
        assert_in_delta(3.0, v.x, DELTA)
        assert_in_delta(4.0, v.y, DELTA)
        assert_in_delta(5.0, v.z, DELTA)
      end
      def test_add_vvector
        u = HVector.new(1,2,3)
        w = HVector.new(4,5,6)
        v = u + w
        assert_in_delta(5.0, v.x, DELTA)
        assert_in_delta(7.0, v.y, DELTA)
        assert_in_delta(9.0, v.z, DELTA)
      end

      def test_subtract_scalar
        u = HVector.new(1,2,3)
        v = u - 2
        assert_in_delta(-1.0, v.x, DELTA)
        assert_in_delta(0.0, v.y, DELTA)
        assert_in_delta(1.0, v.z, DELTA)
      end
      def test_multiply_scalar
        a = 1
        b = 2
        c = 3
        u = HVector.new(a,b,c)
        d = 7.0
        v = u * d
        assert_in_delta(a*d, v.x, DELTA)
        assert_in_delta(b*d, v.y, DELTA)
        assert_in_delta(c*d, v.z, DELTA)
      end
      def test_multiply_vvector
        u = HVector.new(1,2,3)
        v = VVector.new(4,5,6)
        r = u * v
        ans = (1*4+2*5+3*6).to_f
        assert_kind_of(Numeric, r)
        assert_in_delta(ans, r, DELTA)
      end
      def test_multiply_hvector
        u = HVector.new(1,2,3)
        v = HVector.new(4,5,6)
        r = u * v
        ans = (1*4+2*5+3*6).to_f
        assert_kind_of(Numeric, r)
        assert_in_delta(ans, r, DELTA)
      end
    end

    class TestQuaternion < Test::Unit::TestCase
      def setup
        @tr_ones = Quaternion.new(1.0, 1.0, 1.0, 1.0)
        @ind = Quaternion.new(NArray.float(4).indgen(1.0))
      end


      def test_one
        one = Quaternion.new(0,0,0,1.0)
        assert_in_delta(1.0, one.r, DELTA)
        assert_in_delta(0.0, one.i, DELTA)
        assert_in_delta(0.0, one.j, DELTA)
        assert_in_delta(0.0, one.k, DELTA)
      end

      def test_abs
        assert_in_delta(4.0, @tr_ones.abs, DELTA)
        ans = 1.0*1.0 + 2.0*2.0 + 3.0*3.0 + 4.0*4.0
        assert_in_delta(ans, @ind.abs, DELTA)
      end

      def test_conj
        conj =  @ind.conj
        assert_in_delta(-1.0, conj.x, DELTA)
        assert_in_delta(-2.0, conj.y, DELTA)
        assert_in_delta(-3.0, conj.z, DELTA)
        assert_in_delta( 4.0, conj.r, DELTA)
      end
      def test_rotate_in_rad
        q = Quaternion.RotationInRadian(Math::PI/2, 0, 1, 0)
        vec = Quaternion.new(0,0,1)
        r = q * vec * q.conj
        assert_in_delta(1.0, r.x, DELTA)
        assert_in_delta(0.0, r.y, DELTA)
        assert_in_delta(0.0, r.z, DELTA)
      end

    end
  end
end
