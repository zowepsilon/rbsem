class Point
  attr_reader :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def equal(other)
    @x == other.x && @y == other.y
  end
end

class ColorPoint < Point
  attr_reader :color

  def initialize(x, y, color)
    super(x, y)
    @color = color
  end

  # Intersection type: (Point -> bool) & (ColorPoint -> bool)
  # If `other` is only a plain Point (point_test tag in MLsem),
  # return false; otherwise compare x, y, and color.
  def equal(other)
    return false unless other.is_a?(ColorPoint)
    @x == other.x && @y == other.y && @color == other.color
  end
end

class ColorPointFb < Point
  attr_reader :color

  def initialize(x, y, color)
    super(x, y)
    @color = color
  end

  # Self-type only: caller must pass a ColorPointFb.
  # No plain-Point guard — `other.color` is always valid per the contract.
  def equal(other)
    @x == other.x && @y == other.y && @color == other.color
  end
end

class Utils
  def self.call_eq(p1, p2)
    p1.equal(p2)
  end

  def self.control_flow()
    # puts x.nil?

    if true then
      # puts x.nil? # true  

      x = 42

      puts x.nil? # false  

    else
      puts x.nil?
    end

    if true then
      # puts y.nil?
    else
      y = 42
    end
    
    #puts ((z = 12) && z.nil?)
    #puts (w.nil? && (w = 13))

    puts x.nil? # true

    x = 42

    x
  end
end

p1 = Point.new(12, 42)
p2 = ColorPointFb.new(12, 42, "yellow")

# this typechecks (unsoundly)
# either this call or the definition of Utils.call_eq should fail
# puts Utils.call_eq(p2, p1)
Utils.control_flow()

# this line does not type check
# puts p2.equal(p1)