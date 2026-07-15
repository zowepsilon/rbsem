# RbSem

### Usage

You must provide both a ruby file and a RBS file, formatted as `my_file.rb` and `my_file.rbs` in the same directory.

To output the contents to `my_file.ml`:
```
dune exec bin/rbsem.exe -- my_file.rb
```

(You don't need to pass both files)

To output to another file: 
```
dune exec bin/rbsem.exe -- my_file.rb -o some_file.ml
```

To print to stdout directly:
```
dune exec bin/rbsem.exe -- my_file.rb --
```

The output is intended to be pasted into [MLSem](https://e-sh4rk.github.io/MLsem/).

Several tests are available in the [`test/`](test/) folder.

### TODO
- some binary operations for testing
- automatic attr analysis
- attr_reader/attr_writer/attr_accessor