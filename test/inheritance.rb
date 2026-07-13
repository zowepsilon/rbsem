class A 
  attr x
  def initialize() end

  def self.id(x) x end
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
end

class C < B
  attr z
  def initialize() end
end