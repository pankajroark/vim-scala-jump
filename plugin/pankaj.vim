if !exists('loaded_genutils')
  runtime plugin/genutils.vim
endif

exec expand("rubyfile <sfile>:p:h/plug.rb")

function! s:JumpList(word)
  return genutils#GetVimCmdOutput('tselect '.expand(a:word))
endfunction

nmap <leader>]  :call BetterJump()<CR>

function! BetterJump()
:ruby <<EOF
cur_word = VIM::evaluate("expand('<cword>')")
puts "finding tags for #{cur_word}"
jump_list_str = VIM::evaluate("s:JumpList('#{cur_word}')")
jumper = Jumper.new.jump(jump_list_str)
#jumper.jump(jump_list_str)
#import_grabber = ImportsGrabber.new
#import_grabber.get
#puts VIM::evaluate("expand('<cword>')")

EOF

endfunc


function! TestRuby()
:ruby << EOF
 puts Cheese.new.class
EOF
endfunction

function! RubyInfo()

ruby << EOF
 puts RUBY_VERSION
 puts RUBY_PLATFORM 
 puts RUBY_RELEASE_DATE
EOF

endfunction
