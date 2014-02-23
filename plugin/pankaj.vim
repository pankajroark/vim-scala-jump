exec expand("rubyfile <sfile>:p:h/plug.rb")

" copied from genutils
function! s:GetVimCmdOutput(cmd)
  let v:errmsg = ''
  let output = ''
  let _shortmess = &shortmess
  try
    set shortmess=
    redir => output
    silent exec a:cmd
  catch /.*/
    let v:errmsg = substitute(v:exception, '^[^:]\+:', '', '')
  finally
    redir END
    let &shortmess = _shortmess
    if v:errmsg != ''
      let output = ''
    endif
  endtry
  return output
endfunction

function! s:JumpList(word)
  let ic_status = &ignorecase
  " no ignore case
  let &ignorecase = 0
  let jl = s:GetVimCmdOutput('tselect '.expand(a:word))
  " restore original ic flag
  let &ignorecase=ic_status
  return jl
endfunction

nmap <leader>]  :call BetterJump()<CR>

function! BetterJump()
  let orig_shortmess = &shm
  let &shm=orig_shortmess.'s'
  let orig_cmdheight = &cmdheight
  let &cmdheight = 10
:ruby <<EOF
cur_word = VIM::evaluate("expand('<cword>')")
jump_list_str = VIM::evaluate("s:JumpList('#{cur_word}')")
Jumper.new.jump(jump_list_str)
#jumper.jump(jump_list_str)
#import_grabber = ImportsGrabber.new
#import_grabber.get
#puts VIM::evaluate("expand('<cword>')")

EOF

let &shm=orig_shortmess
let &cmdheight = orig_cmdheight
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
