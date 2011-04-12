= prefetch-rspec

Prefetch RSpec is prefetch initialize phase before run rspec.

= Install

  $ gem install prefetch-rspec

= Using with Rails3

Change config/environments/tests.rb cache_classess line.

  config.cache_classes = ENV.has_key?('PRSPEC') ? false : true

Execute command Rails.root

  $ prspecd --rails

or copy examples/rails.prspecd to Rails.root/.rspecd 

  $ prspecd

run prspec

  $ prspec [rspec arguments]
  example..
  $ prspec spec/models/example.rb -l 5

= License

MIT License

 Copyright (c) 2010-2011 Asakusa.rb 
  
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
  
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
  
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

