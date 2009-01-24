require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'cgi'

# Given a string with a module name, find all constants recognized for this
# module and prefix them with ModuleName:: to correctly parse them later.
def module_classes(module_name)
  eval(module_name).constants.collect{|x| module_name + "::" + x}
end

# Given an array of string constant names, determine whether they are classes or
# modules, and for modules recursively fetch their included classes / included
# modules.
# 
# Level variable serves as a limiting factor to avoid infinite loops — this
# scripts limits recursion to two levels.
def classify(constants, level=0)
  classes = []
  modules = []
  constants.each do |constant|
    is_class = eval(constant).class
    classes << constant if is_class == Class
    modules << constant if is_class == Module
  end
  unless modules.empty? || level == 2
    i = modules.collect{|x| classify(module_classes(x), level+1)}
    classes << i[0]
    modules << i[1]
  end
  [classes.flatten, modules.flatten]
end

# Given an array of sorted (classes/modules) constants, fetch the list of class
# methods of the classes, create a new instance of each class and fetch the list
# of their methods (special case made for CGI class that requires input to be
# initialized and halts the program indefinitely; also, for classes that 
# require some arguments to be initialized, ArgumentError is raised and 
# silently handled).
#
# Also, add a list of all module methods. Flatten the methods list, weed 
# duplicates and sort the list.
def methodify(constants)
  classes = constants[0]
  modules = constants[1]
  methods = []
  
  classes.each do |cla|
    methods << eval(cla).methods
    begin
      unless cla == "CGI"
        methods << eval(cla).new.methods
      end
    rescue
    end
  end
  
  modules.each do |mod|
    methods << eval(mod).methods
  end
  
  methods.flatten.uniq.sort
end

counts = {}

methods = methodify(classify(Module.constants))
p methods.length
# Collect only methods that start with a lowercase letter or an underscore.
methods = methods.collect{|x| x if x =~ /([a-z]|_).+/}.compact
methods.each do |method|  
  # Only find method names prefixed by dot and suffixed by either whitespace,
  # another dot, opening or closing parentheses or curly braces.
  doc = Hpricot.XML(open("http://www.google.com/codesearch/feeds/search?q=" + CGI.escape("\\.#{method}(\\s|\\.|\\(|\\{|\\)|\\})") + "+lang:ruby&v=2"))
  count = doc.at("//opensearch:totalResults").inner_html.to_i
  counts[method] = count
end

# Sort and print the output.
p counts.sort{|a, b| b[1]<=>a[1]}