class Test
  def self.swap(b)
    x = 1
    y = 2

    if b then
      z = x
      x = y
      y = z
    end

    x
  end

  def self.swap_precise(b)
    x = 1
    y = 2

    if b then
      z = x
      x = y
      y = z
    end

    x
  end
end

    