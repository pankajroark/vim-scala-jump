class JumpEntry
  def initialize(filepath, regex)
    @filepath = filepath
    @regex = regex
  end
  attr_accessor :filepath
  attr_accessor :regex
end

class Jumper
  # jump list is the typical tselect list
  # format
  # ignore first line
  # Split rest of the lines into bunches of 3
  # The first line has the file path as last element
  # Third line has the regular expression to use to jump
  # to line in that file
  def jump(jump_list_str)
    jump_list = jump_list_str.split("\n")
    clean_up_jump_list(jump_list)
    jump_entries = get_jump_entries(jump_list)
    best_jump_entry = find_best_jump_entry(jump_entries)
    puts "best jump entry : #{best_jump_entry.filepath}"
    jump_to_entry(best_jump_entry)
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
    same_file_entries = in_same_file(jump_entries)
    if(!same_file_entries.empty?)
      puts "found in same file"
      return same_file_entries.first
    end

    same_dir_entries = in_same_dir(jump_entries)
    if(!same_dir_entries.empty?)
      puts "found in same directory"
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
    jump_entries.each do | jump_entry|
      filepath = jump_entry.filepath
      match_count = imports_match_count(filepath, imports)
      if(match_count > best_match_count)
        best_match_count = match_count
        best_entry = jump_entry
      end
    end
    puts "best entry has match count of #{best_match_count}"
    best_entry
  end

  # imports are array of dot separated parts
  # path is a file path
  def imports_match_count(filepath, imports)
    max = 0
    imports.each do |import_path|
      match_count = import_match_count(filepath, import_path)
      if (match_count > max)
        max = match_count
      end
    end
    max
  end

  # path is a filepath
  # import is dot separated parts
  def import_match_count(filepath, import)
    import_path = import.gsub(".", "/")
    filepath_minus_extension = drop_extension(filepath)

    lcs = find_longest_common_substring(import_path, filepath_minus_extension) 
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

  def drop_extension filepath
    parts = filepath.split('/')
    filename = parts.pop
    filename_minus_extension = filename.split('.').first
    parts << filename_minus_extension
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
  # , it would return
  # [ 'com.twitter.some',  'com.twitter.other']
  def get
    import_lines =  lines.select do |line|
      line.start_with? "import"
    end
    import_lines.map do |line|
      line.split(/\s+/).last
    end
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
