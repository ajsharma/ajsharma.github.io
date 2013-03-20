## tl:dr

Jekyll does not like ruby 2.0.  The simple workaround is to go back to ruby 1.9.

## The default setup

Here's the steps I used to create the page on Github

 1. Use GitHub to create the `ajsharma.github.com` respository
 2. Cloned the repo to my MacBook Pro with OSX 10.8.3 `git clone https://github.com/ajsharma/ajsharma.github.com.git` which created a `ajsharma.github.com` folder with the GitHub default code.
 3. GitHub provides the details on their jekyll configuration, so let's wrap that in a shell script.  The `--server --auto` tags are mine so that I can work in a rails-like environment.

```
#! /usr/bin/env bash
jekyll --pygments --no-lsi --safe --server --auto
```

## But Oh No!  A Wild `No iconv` Appears!

`./start-jekyll.sh` led to:

```bash
/Users/ajsharma/.rvm/rubies/ruby-2.0.0-p0/lib/ruby/2.0.0/rubygems/core_ext/kernel_require.rb:45:in `require': cannot load such file -- iconv (LoadError)
    from /Users/ajsharma/.rvm/rubies/ruby-2.0.0-p0/lib/ruby/2.0.0/rubygems/core_ext/kernel_require.rb:45:in `require'
    from /Users/ajsharma/.rvm/gems/ruby-2.0.0-p0@ajsharma.github.com/gems/maruku-0.6.0/lib/maruku/input/parse_doc.rb:22:in `<top (required)>'
    from /Users/ajsharma/.rvm/rubies/ruby-2.0.0-p0/lib/ruby/2.0.0/rubygems/core_ext/kernel_require.rb:45:in `require'
    from /Users/ajsharma/.rvm/rubies/ruby-2.0.0-p0/lib/ruby/2.0.0/rubygems/core_ext/kernel_require.rb:45:in `require'
    from /Users/ajsharma/.rvm/gems/ruby-2.0.0-p0@ajsharma.github.com/gems/maruku-0.6.0/lib/maruku.rb:85:in `<top (required)>'
    from /Users/ajsharma/.rvm/rubies/ruby-2.0.0-p0/lib/ruby/2.0.0/rubygems/core_ext/kernel_require.rb:45:in `require'
    from /Users/ajsharma/.rvm/rubies/ruby-2.0.0-p0/lib/ruby/2.0.0/rubygems/core_ext/kernel_require.rb:45:in `require'
    from /Users/ajsharma/.rvm/gems/ruby-2.0.0-p0@ajsharma.github.com/gems/jekyll-0.12.0/lib/jekyll.rb:26:in `<top (required)>'
    from /Users/ajsharma/.rvm/rubies/ruby-2.0.0-p0/lib/ruby/2.0.0/rubygems/core_ext/kernel_require.rb:45:in `require'
    from /Users/ajsharma/.rvm/rubies/ruby-2.0.0-p0/lib/ruby/2.0.0/rubygems/core_ext/kernel_require.rb:45:in `require'
    from /Users/ajsharma/.rvm/gems/ruby-2.0.0-p0@ajsharma.github.com/gems/jekyll-0.12.0/bin/jekyll:20:in `<top (required)>'
    from /Users/ajsharma/.rvm/gems/ruby-2.0.0-p0@ajsharma.github.com/bin/jekyll:23:in `load'
    from /Users/ajsharma/.rvm/gems/ruby-2.0.0-p0@ajsharma.github.com/bin/jekyll:23:in `<main>'
```

which is a complaint about the lack of `iconv` in my ruby 2.0.0 installation.  This [this StackOverflow answer](http://stackoverflow.com/questions/7829886/in-require-no-such-file-to-load-iconv-loaderror) suggested [reinstalling ruby](https://rvm.io/packages/iconv/) which is enough to make me paranoid about breaking all my other ruby 2.0.0 rails projects, but no guts, no glory.

### The attempted reinstall

```bash
rvm pkg install iconv
rvm reinstall 2.0.0 --with-iconv-dir=$rvm_path/usr
```

Which at first appeared to run successfully, but. sadly, with a little hiccup along the way:

```bash
Removing /Users/ajsharma/.rvm/src/ruby-2.0.0-p0...
...
Error running 'env GEM_PATH=/Users/ajsharma/.rvm/gems/ruby-2.0.0-p0:/Users/ajsharma/.rvm/gems/ruby-2.0.0-p0@global:/Users/ajsharma/.rvm/gems/ruby-2.0.0-p0:/Users/ajsharma/.rvm/gems/ruby-2.0.0-p0@global GEM_HOME=/Users/ajsharma/.rvm/gems/ruby-2.0.0-p0 /Users/ajsharma/.rvm/rubies/ruby-2.0.0-p0/bin/ruby -d /Users/ajsharma/.rvm/src/rubygems-2.0.3/setup.rb --verbose',
please read /Users/ajsharma/.rvm/log/ruby-2.0.0-p0/rubygems.install.log
Installation of rubygems did not complete successfully.
...
Making gemset ruby-2.0.0-p0@global pristine....

```

So, not great.  The jekyll error still persists.

## Nope, not fixing this

Ok, instinct says this is not a RVM issue, it's a ruby 2.0 problem.  So, let's go old school.

```bash
rvm use ruby-1.9.3-p392
rvm --rvmrc --create ruby-1.9.3-p392@ajsharma.github.com
bundle install
```

## Try this again

Now in the nice old ruby-1.9.3, I run my shell script again and get:

```
/Users/ajsharma/.rvm/gems/ruby-1.9.3-p392@ajsharma.github.com/gems/maruku-0.6.0/lib/maruku/input/parse_doc.rb:22:in `<top (required)>': iconv will be deprecated in the future, use String#encode instead.
Building site: /Users/ajsharma/Projects/ajsharma.github.com -> /Users/ajsharma/Projects/ajsharma.github.com/_site
```

a deprecation warning, one that I'd come across while investigating the error.  And, hurray the site is created!