class A 
  attr x
  def initialize() end

  def x() @x end

  def id(x) x.x end
end

class B < A
  attr y
  def initialize() end

  def choose(b)
    if b then
      @x
    else
      @y
    end
  end

  def y() @y end
  def id(x) x.y end
end

class C < B
  attr z
  def initialize() end

  def z() @z end
end

class Other
  def cast(x) x end

  def self.test()
    a = A.new()
    b = B.new()
    self.cast(b).id(a)
  end
end