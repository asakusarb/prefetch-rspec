
watch('(lib/*.rb)|(spec/*.rb)') {|md| system("rspec spec/prefetch_rspec_spec.rb") }
