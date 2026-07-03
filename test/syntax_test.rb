class A
  def self.hello(y)
    if x
      y
    else
      z
    end
  end

  def id(x)
    y = x
    @r = @b
    @b = self
    x
  end

  attr r
  attr g
  attr b
end

class B < A
  def id(x)
    x
  end

  def initialize(x)
  end

  def lit(a)
    1215
    true
    false
    :irif
    A
    nil
    self.f(true)
    return 42
  end
end