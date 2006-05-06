##
## $Rev$
## $Release$
## $Copyright$
##


require 'erubis/engine'


module Erubis


  ##
  ## switch '<%= ... %>' to escaped and '<%== ... %>' to unescaped
  ##
  ## ex.
  ##   class XmlEruby < Eruby
  ##     include EscapeEnhancer
  ##   end
  ##
  ## this is language-indenedent.
  ##
  module EscapeEnhancer

    def self.desc   # :nodoc:
      "switch '<%= %>' to escaped and '<%== %>' to unescaped"
    end

    #--
    #def self.included(klass)
    #  klass.class_eval <<-END
    #    alias _add_expr_literal add_expr_literal
    #    alias _add_expr_escaped add_expr_escaped
    #    alias add_expr_literal _add_expr_escaped
    #    alias add_expr_escaped _add_expr_literal
    #  END
    #end
    #++

    def add_expr(src, code, indicator)
      case indicator
      when '='
        add_expr_escaped(src, code)
        #add_expr_literal(src, code)
      when '=='
        add_expr_literal(src, code)
        #add_expr_escaped(src, code)
      when '==='
        add_expr_debug(src, code)
      end
    end

  end


  #--
  ## (obsolete)
  #module FastEnhancer
  #end
  #++


  ##
  ## use $stdout instead of string
  ##
  ## this is only for Eruby.
  ##
  module StdoutEnhancer

    def self.desc   # :nodoc:
      "use $stdout instead of array buffer or string buffer"
    end

    def add_preamble(src)
      src << "_out = $stdout;"
    end

    def add_postamble(src)
      src << "\n''\n"
    end

  end


  ##
  ## use print statement instead of '_out << ...'
  ##
  ## this is only for Eruby.
  ##
  module PrintOutEnhancer

    def self.desc   # :nodoc:
      "use print statement instead of '_out << ...'"
    end

    def add_preamble(src)
    end

    def add_text(src, text)
      src << " print '" << escape_text(text) << "';" unless text.empty?
    end

    def add_stmt(src, code)
      src << code << ';'
    end

    def add_expr_literal(src, code)
      src << ' print((' << code << ').to_s);'
    end

    def add_expr_escaped(src, code)
      src << ' print ' << escaped_expr(code) << ';'
    end

    def add_postamble(src)
      src << "\n" unless src[-1] == ?\n
    end

  end


  ##
  ## enable print function
  ##
  ## Notice: use Eruby#evaluate() and don't use Eruby#result()
  ## to be enable print function.
  ##
  ## this is only for Eruby.
  ##
  module PrintEnabledEnhancer

    def self.desc   # :nodoc:
      "enable to use print statement in '<% %>'"
    end

    def add_preamble(src)
      src << "@_out = "
      super
    end

    def print(*args)
      args.each do |arg|
        @_out << arg.to_s
      end
    end

  end


  ##
  ## return array instead of string
  ##
  ## this is only for Eruby.
  ##
  module ArrayEnhancer

    def self.desc   # :nodoc:
      "return array instead of string"
    end

    def add_preamble(src)
      src << "_out = [];"
    end

    def add_postamble(src)
      src << "\n" unless src[-1] == ?\n
      src << "_out\n"
    end

  end


  ##
  ## use array buffer instead of string buffer (included in Eruby by default)
  ##
  ## this is only for Eruby.
  ##
  module ArrayBufferEnhancer

    def self.desc   # :nodoc:
      "use array buffer instead of string (included in Eruby by default)"
    end

    def add_preamble(src)
      src << "_out = [];"
    end

    def add_postamble(src)
      src << "\n" unless src[-1] == ?\n
      src << "_out.join\n"
    end

  end


  ##
  ## use string buffer instead of array buffer
  ##
  ## this is only for Eruby.
  ##
  module StringBufferEnhancer

    def self.desc   # :nodoc:
      "use string buffer instead of array buffer"
    end

    def add_preamble(src)
      src << "_out = '';"
    end

    def add_postamble(src)
      src << "\n" unless src[-1] == ?\n
      src << "_out\n"
    end

  end


  ##
  ## get compile faster, but spaces around '<%...%>' are not trimmed.
  ##
  ## this is language-independent.
  ##
  module SimplifyEnhancer

    def self.desc   # :nodoc:
      "get compile faster but leave spaces around '<% %>'"
    end

    #DEFAULT_REGEXP = /(.*?)(^[ \t]*)?<%(=+|\#)?(.*?)-?%>([ \t]*\r?\n)?/m
    SIMPLE_REGEXP = /(.*?)<%(=+|\#)?(.*?)-?%>/m

    def compile(input)
      src = ""
      add_preamble(src)
      #regexp = pattern_regexp(@pattern)
      input.scan(SIMPLE_REGEXP) do |text, indicator, code|
        add_text(src, text)
        if !indicator              # <% %>
          add_stmt(src, code)
        elsif indicator[0] == ?\#  # <%# %>
          n = code.count("\n")
          add_stmt(src, "\n" * n)
        else                       # <%= %>
          add_expr(src, code, indicator)
        end
      end
      rest = $' || input
      add_text(src, rest)
      add_postamble(src)
      return src
    end

  end


  ##
  ## enable to use other embedded expression pattern (default is '\[= =\]').
  ##
  ## notice! this is an experimental. spec may change in the future.
  ##
  ## ex.
  ##   input = <<END
  ##   <% for item in list %>
  ##     <%= item %> : <%== item %>
  ##     [= item =] : [== item =]
  ##   <% end %>
  ##   END
  ##
  ##   class BiPatternEruby
  ##     include BiPatternEnhancer
  ##   end
  ##   eruby = BiPatternEruby.new(input, :bipattern=>'\[= =\]')
  ##   list = ['<a>', 'b&b', '"c"']
  ##   print eruby.result(binding())
  ##
  ##   ## output
  ##     <a> : &lt;a&gt;
  ##     <a> : &lt;a&gt;
  ##     b&b : b&amp;b
  ##     b&b : b&amp;b
  ##     "c" : &quot;c&quot;
  ##     "c" : &quot;c&quot;
  ##
  ## this is language independent.
  ##
  module BiPatternEnhancer

    def self.desc   # :nodoc:
      "another embedded expression pattern (default '\[= =\]')."
    end

    def initialize(input, properties={})
      self.bipattern = properties[:bipattern]    # or '\$\{ \}'
      super
    end

    ## when pat is nil then '\[= =\]' is used
    def bipattern=(pat)   # :nodoc:
      @bipattern = pat || '\[= =\]'
      pre, post = @bipattern.split()
      @bipattern_regexp = /(.*?)#{pre}(=*)(.*?)#{post}/m
    end

    def add_text(src, text)
      return unless text
      text.scan(@bipattern_regexp) do |txt, indicator, code|
        super(src, txt)
        add_expr(src, code, '=' + indicator)
      end
      rest = $' || text
      super(src, rest)
    end

  end


  ##
  ## regards lines starting with '%' as program code
  ##
  ## this is for compatibility to eruby and ERB.
  ##
  ## this is language-independent.
  ##
  module PercentLineEnhancer

    def self.desc   # :nodoc:
      "regard lines starting with '%' as program code"
    end

    PERCENT_LINE_PATTERN = /(.*?)^\%(.*?\r?\n)/m

    def add_text(src, text)
      text.scan(PERCENT_LINE_PATTERN) do |txt, line|
        super(src, txt)
        if line[0] == ?%
          super(src, line)
        else
          add_stmt(src, line)
        end
      end
      rest = $' || text
      super(src, rest)
    end

  end


  ##
  ## [experimental] allow header and footer in eRuby script
  ##
  ## ex.
  ##   ====================
  ##   ## without header and footer
  ##   $ cat ex1.eruby
  ##   <% def list_items(list) %>
  ##   <%   for item in list %>
  ##   <li><%= item %></li>
  ##   <%   end %>
  ##   <% end %>
  ##
  ##   $ erubis -s ex1.eruby
  ##   _out = []; def list_items(list)
  ##   ;   for item in list
  ##   ; _out << '<li>'; _out << ( item ).to_s; _out << '</li>
  ##   ';   end
  ##   ; end
  ##   ;
  ##   _out.join
  ##
  ##   ## with header and footer
  ##   $ cat ex2.eruby
  ##   <!--#header:
  ##   def list_items(list)
  ##    #-->
  ##   <%  for item in list %>
  ##   <li><%= item %></li>
  ##   <%  end %>
  ##   <!--#footer:
  ##   end
  ##    #-->
  ##
  ##   $ erubis -s -c HeaderFooterEruby ex4.eruby
  ##
  ##   def list_items(list)
  ##    _out = []; _out << '
  ##   ';  for item in list
  ##   ; _out << '<li>'; _out << ( item ).to_s; _out << '</li>
  ##   ';  end
  ##   ; _out << '
  ##   ';
  ##   _out.join
  ##   end
  ##
  ##   ====================
  ##
  ## this is language-independent.
  ##
  module HeaderFooterEnhancer

    def self.desc   # :nodoc:
      "allow header/footer in document (ex. '<!--#header: #-->')"
    end

    HEADER_FOOTER_PATTERN = /(.*?)(^[ \t]*)?<!--\#(\w+):(.*?)\#-->([ \t]*\r?\n)?/m

    def add_text(src, text)
      text.scan(HEADER_FOOTER_PATTERN) do |txt, lspace, word, content, rspace|
        flag_trim = @trim && lspace && rspace
        super(src, txt)
        content = "#{lspace}#{content}#{rspace}" if flag_trim
        super(src, lspace) if !flag_trim && lspace
        instance_variable_set("@#{word}", content)
        super(src, rspace) if !flag_trim && rspace
      end
      rest = $' || text
      super(src, rest)
    end

    attr_accessor :header, :footer

    def compile(input)
      source = super
      return @src = "#{@header}#{source}#{@footer}"
    end

  end


end