module Util
  def Util.drop_extension filepath
    parts = filepath.split('/')
    filename = parts.pop
    filename_minus_extension = filename.split('.').first
    parts << filename_minus_extension
    parts.join('/')
  end

  def Util.get_filename filepath
    parts = filepath.split('/')
    parts.last
  end

  def Util.get_filename_parts filename
    filename.split('.')
  end

  def Util.log msg
    VIM::message msg
  end
end

class JumpEntry

  attr_accessor :filepath
  attr_accessor :regex
  attr_reader :filepath_without_extension

  def initialize(filepath, regex)
    @filepath = filepath
    @regex = regex
    @filepath_without_extension = Util.drop_extension filepath
  end

end

class Jumper
  # jump list is the typical tselect list
  # format
  # The first line has the file path as last element
  # Last line has the regular expression to use to jump
  # to line in that file
  # Some results span 3 lines, some 2 leading to unavoidable complexity
  def jump(jump_list_str)
    jump_list = jump_list_str.split("\n")
    clean_up_jump_list(jump_list)
    jump_entries = get_jump_entries(jump_list)
    if(jump_entries.empty?)
      Util.log "no matches found"
      return
    end
    jump_entries = filter_jump_entries(jump_entries)
    if(jump_entries.empty?)
      Util.log "matches found but filtered out"
      return
    end
    best_jump_entry = find_best_jump_entry(jump_entries)
    Util.log("best jump entry : #{best_jump_entry.filepath}")
    jump_to_entry(best_jump_entry)
  end

  # Filter out spec files
  # Filter out files other than java/scala
  def filter_jump_entries jump_entries
    jump_entries.select do |jump_entry|
      filepath = jump_entry.filepath
      filename = Util.get_filename(filepath)
      subname, ext = Util.get_filename_parts filename
      !subname.end_with?('Spec') && (ext == 'java' || ext == 'scala')
    end
  end

  def jump_to_entry jump_entry
    path = jump_entry.filepath
    regex = jump_entry.regex
    VIM::command("edit #{path}")
    VIM::command("/\\V#{regex}")
  end

  def v_file_path
    VIM::evaluate("expand('%:p')")
  end

  def v_file_dir
    VIM::evaluate("expand('%:p:h')")
  end

  def find_best_jump_entry(jump_entries)
    if jump_entries.length == 1
      Util.log "only one match"
      return jump_entries[0]
    end

    same_file_entries = in_same_file(jump_entries)
    if(!same_file_entries.empty?)
      Util.log "found in same file"
      return same_file_entries.first
    end

    same_dir_entries = in_same_dir(jump_entries)
    if(!same_dir_entries.empty?)
      Util.log "found in same directory"
      return same_dir_entries.first
    end

    best_match_on_import(jump_entries, ImportsGrabber.new.get)
  end

  def in_same_file(jump_entries)
    file_path = v_file_path()
    jump_entries.select do |jump_entry|
      path = jump_entry.filepath
      path == file_path
    end
  end

  def in_same_dir jump_entries
    dir = v_file_dir
    jump_entries.select do |jump_entry|
      jump_entry_path = jump_entry.filepath
      jump_entry_dir = dir_from_filepath(jump_entry_path)
      dir == jump_entry_dir
    end
  end

  def best_match_on_import(jump_entries, imports)
    # find the entry that matches the most with import paths
    best_entry = jump_entries.first
    best_match_count = -1
    jump_entries.each do |jump_entry|
      filepath_without_extension = jump_entry.filepath_without_extension
      match_count = imports_match_count(filepath_without_extension, imports)
      if(match_count > best_match_count)
        best_match_count = match_count
        best_entry = jump_entry
      end
    end
    Util.log "best entry has match count of #{best_match_count}"
    best_entry
  end

  # imports are array of dot separated parts
  # path is a file path
  def imports_match_count(filepath_without_extension, imports)
    max = 0
    imports.each do |import_path|
      match_count = import_match_count(filepath_without_extension, import_path)
      if (match_count > max)
        max = match_count
      end
    end
    max
  end

  # path is a filepath
  # import is dot separated parts
  def import_match_count(filepath_without_extension, import)
    lcs = find_longest_common_substring(import, filepath_without_extension) 
    #puts "#{filepath} - #{import_path} : #{lcs}"
    lcs.split("/").length
  end

  def find_longest_common_substring(s1, s2)
    if (s1 == "" || s2 == "")
      return ""
    end
    m = Array.new(s1.length){ [0] * s2.length }
    longest_length, longest_end_pos = 0,0
    (0 .. s1.length - 1).each do |x|
      (0 .. s2.length - 1).each do |y|
        if s1[x] == s2[y]
          m[x][y] = 1
          if (x > 0 && y > 0)
            m[x][y] += m[x-1][y-1]
          end
          if m[x][y] > longest_length
            longest_length = m[x][y]
            longest_end_pos = x
          end
        end
      end
    end
    return s1[longest_end_pos - longest_length + 1 .. longest_end_pos]
  end

  def dir_from_filepath filepath
    parts = filepath.split('/')
    parts.pop
    parts.join('/')
  end

  def clean_up_jump_list(jump_list)
    jump_list.shift
    jump_list.shift
    jump_list.pop
  end

  def get_jump_entries(jump_list)
    jump_entries = Array.new
    last_line = nil
    filepath = nil
    regex = nil
    jump_list.each do |line|
      if entry_start?(line)
        if(!last_line.nil?)
          regex = last_line.strip
          jump_entries << JumpEntry.new(filepath.clone, regex.clone)
        end
        parts = line.split(/\s+/)
        filepath = parts.last
      else 
        last_line = line
      end
    end
    if (!(filepath.nil? || last_line.nil?))
      regex = last_line.strip
      jump_entries << JumpEntry.new(filepath.clone, regex.clone)
    end
    jump_entries
  end

  def entry_start? line
    !(line.match(/^ *\d+ /).nil?)
  end
end

class ImportsGrabber
  # Returns import patterns
  # e.g. for 
  # import com.twitter.some
  # import com.twitter.other
  # import com.twitter.{ one, two }
  # , it would return
  # [ 'com.twitter.some',  'com.twitter.other']
  def get
    import_lines = get_import_lines_from_file()
    dotted_parts = extract_dotted_part import_lines
    imports = get_import_components dotted_parts
    imports.map do |import|
      import.to_path
    end
  end

  def get_import_lines_from_file
    import_lines =  lines.select do |line|
      line.start_with? "import"
    end
  end

  def extract_dotted_part import_lines
    import_lines.map do |line|
      dotted_part = line.split(/\s+/).last
    end
  end

  # takes "com.twitter.some" or "com.twitter.{one, two}"
  # @return array of Import objects
  def get_import_components dotted_parts
    aofa = dotted_parts.map do |dotted_part|
      dotted_part_to_import dotted_part
    end
    aofa.flatten
  end

  # @return array of Import objects
  def dotted_part_to_import dotted
    parts = dotted.split('.')
    components_str = parts.pop # parts modified here
    if (components_str.start_with? '{')
      comma_sep_contents = uncurly(components_str)
      components = comma_sep_contents.split(/\s*,\s*/)
      components.map do |component|
        # component may be a mapping, eg. a => b
        actual_component = import_mapping_to_import component
        Import.new(parts.clone << actual_component)
      end
    else
      # put back the last part
      parts << components_str
      [ Import.new(parts.clone) ]
    end
  end

  # @param import_mapping_str e.g. a => b or simple a
  def import_mapping_to_import maybe_import_mapping_str
    if (maybe_import_mapping_str.include? '=>')
      component_parts = maybe_import_mapping_str.split('=>')
      component_parts[0].strip
    else
      maybe_import_mapping_str 
    end
  end

  def uncurly str
    str.gsub(/[{}]/, " ").strip
  end

  def lines
    lines_count = $curbuf.count
    lines = Array.new
    (1..lines_count).each do |line_number|
      lines << $curbuf[line_number]
    end
    lines
  end
end

class Import
  attr_reader :parts
  def initialize(parts)
    @parts = parts
  end

  def to_s
    @parts.join('.')
  end

  def to_path
    @parts.join('/')
  end
end
