---
layout: default
title: Getting Started with Jekyll and GitHub Pages
---

This is a simple story about how I got [GitHub's Pages](http://pages.github.com/) installation to work locally, and some of the challenges I ran into.

## tl:dr

Jekyll does not like ruby 2.0.  The simple workaround is to go back to ruby 1.9.

## The Default Setup

Here's the steps I used to create the page on GitHub:

I used GitHub to create the [ajsharma.github.com](https://github.com/ajsharma/ajsharma.github.com) repository.

I then cloned the repository to my MacBook Pro with OSX 10.8.3 `git clone https://github.com/ajsharma/ajsharma.github.com.git`.

The usual git workflow so far.

## Tweaks

In order to get the source code to turn into a web site, I needed some configurations.

GitHub provides the [details](https://help.github.com/articles/using-jekyll-with-pages) on their Jekyll configuration, so I wrapped that in a shell script.  The `--server --auto` tags are mine so that I could work in a rails-like environment.

{% highlight bash %}
#! /usr/bin/env bash
jekyll --pygments --no-lsi --safe --server --auto
{% endhighlight %}

I got a Gemfile going too, that'll make it easier to deploy to new machines as needed.

{% highlight bash %}
# A sample Gemfile
source "https://rubygems.org"

# gem "rails"
gem 'jekyll',     '=0.12.0'
gem 'liquid',     '=2.4.1'
gem 'redcarpet',  '=2.1.1'
gem 'maruku',     '=0.6.0'
gem 'rdiscount',  '=1.6.8'
gem 'RedCloth',   '=4.2.9'
{% endhighlight %}

Also, I didn't want to pollute my global gemset, so I setup a `.rvmrc` file: `rvm --rvmrc --create ruby-2.0.0-p0@ajsharma.github.com`.  Then, all it should take to run is: `bundle install` and a `./start-jekyll.sh`.

## But Oh No!  A Wild `No iconv` Appears!

Running `./start-jekyll.sh` led to:

{% highlight bash %}
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
{% endhighlight %}

which is a complaint about the lack of `iconv` in my ruby 2.0.0 installation.  This [this StackOverflow answer](http://stackoverflow.com/questions/7829886/in-require-no-such-file-to-load-iconv-loaderror) suggested [reinstalling ruby](https://rvm.io/packages/iconv/) which was enough to make me paranoid about breaking all my other ruby 2.0.0 rails projects, but no guts, no glory.

### The Attempted Reinstall

{% highlight bash %}
rvm pkg install iconv
rvm reinstall 2.0.0 --with-iconv-dir=$rvm_path/usr
{% endhighlight %}

Which at first appeared to run successfully, but sadly, with a little hiccup along the way:

{% highlight text %}
Removing /Users/ajsharma/.rvm/src/ruby-2.0.0-p0...
...
Error running 'env GEM_PATH=/Users/ajsharma/.rvm/gems/ruby-2.0.0-p0:/Users/ajsharma/.rvm/gems/ruby-2.0.0-p0@global:/Users/ajsharma/.rvm/gems/ruby-2.0.0-p0:/Users/ajsharma/.rvm/gems/ruby-2.0.0-p0@global GEM_HOME=/Users/ajsharma/.rvm/gems/ruby-2.0.0-p0 /Users/ajsharma/.rvm/rubies/ruby-2.0.0-p0/bin/ruby -d /Users/ajsharma/.rvm/src/rubygems-2.0.3/setup.rb --verbose',
please read /Users/ajsharma/.rvm/log/ruby-2.0.0-p0/rubygems.install.log
Installation of rubygems did not complete successfully.
...
Making gemset ruby-2.0.0-p0@global pristine....

{% endhighlight %}

So, not great.  The Jekyll error still persisted.

## Nope, not fixing this

Ok, instinct said this was not a RVM issue, it was a ruby 2.0 problem.  So, go old school.

{% highlight bash %}
rvm use ruby-1.9.3-p392
rvm --rvmrc --create ruby-1.9.3-p392@ajsharma.github.com
bundle install
{% endhighlight %}

## Try this again

Now in the nice old ruby-1.9.3, I ran my shell script again and got:

{% highlight bash %}
/Users/ajsharma/.rvm/gems/ruby-1.9.3-p392@ajsharma.github.com/gems/maruku-0.6.0/lib/maruku/input/parse_doc.rb:22:in `<top (required)>': iconv will be deprecated in the future, use String#encode instead.
Building site: /Users/ajsharma/Projects/ajsharma.github.com -> /Users/ajsharma/Projects/ajsharma.github.com/_site
{% endhighlight %}

a deprecation warning, one that I'd come across while investigating the error.  And, hurray the site is created!