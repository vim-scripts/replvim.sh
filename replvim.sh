#!/bin/sh


[ "X$3" != 'X' ] || { cat << EOUSE ; exit 1 ; }

 Usage : $0 replname code_type file

Runs a screen/vim session on the given file so that one window
holds a repl and another window holds vim. 
Hit:
<leader>e   to eval the current expression 
<leader>r   to evaluate the given marked range
ctrl-a \    to exit everything 
Set the leader in vim with 
:let mapleader = "," 
replacing "," with the key you like the most

Arguments (wrap these in an alias or sh script):
 replname   The repl being used (ocaml, bigloo have been tested)
 code_type  Can be 'lisp' for lisp-like or 'ocaml'

Requires (on your PATH):
  socat (www.dest-unreach.org/socat/)
  screen (http://www.gnu.org/software/screen/)
if you don't have these your life will be much richer for obtaining them

(at saul (dot alien-science org)) welcomes your fixes and extensions

EOUSE

########################################
#### Contains DNA from from VIlisp.vim 
####  By Larry Clapp <vim@theclapp.org>
########################################

##### Configuration

repl=$1
code_type=$2

##### Setup

temp_dir=/tmp/tmp_for_$$
vim_script=$temp_dir/replvim.vim
pipe=$temp_dir/replvim.pipe
screen_rc=$temp_dir/replscreen.rc
scratch_file=$temp_dir/replvim_scratch

# The vim commands used to yank the beginning and ending
# of a block to eval into vim register 'y'
# The actual vim script functions are defined later
if [ "X$code_type" = 'Xocaml' ] 
then
   find_vim_block='    call REPLWIN_ocaml_block()'
elif [ "X$code_type" = 'Xlisp' ]
then
   find_vim_block='    call REPLWIN_lispy_block()'
fi

### Start of code
mkdir $temp_dir

### Define a vi script to do evaluation

cat << EOVIM > $vim_script
" Run a repl from vim

" ====== Get the current position in the current buffer
function! REPLWIN_get_pos()
  " what buffer are we in?
  let bufname = bufname( "%" )

  " get current position
  let c_cur = virtcol( "." )
  let l_cur = line( "." )
  normal! H
  let l_top = line( "." )

  let pos = bufname . "|" . l_top . "," . l_cur . "," . c_cur

  " go back
  exe "normal! " l_cur . "G" . c_cur . "|"

  return( pos )
endfunction

" ===== Sets the given position in the given buffer
function! REPLWIN_set_pos( pos )
  let mx = '\(\f\+\)|\(\d\+\),\(\d\+\),\(\d\+\)'
  let bufname = substitute( a:pos, mx, '\1', '' )
  let l_top = substitute( a:pos, mx, '\2', '' )
  let l_cur = substitute( a:pos, mx, '\3', '' )
  let c_cur = substitute( a:pos, mx, '\4', '' )

  exe "bu" bufname
  exe "normal! " . l_top . "Gzt" . l_cur . "G" . c_cur . "|"
endfunction

" ===== Get a block of lisp-like data
function! REPLWIN_lispy_block()
  exe "normal! ?(\<cr>"
  exe "normal! \\"ly%\<cr>"
endfunction

" ===== Get a block of ocaml data
function! REPLWIN_ocaml_block()
  let pos = REPLWIN_get_pos()
  let present = line(".")
  exe "normal! 0\?;;\<cr>"
  let last = line(".")
  if present > last
      exe "normal! j0\\"ly\/;;\<cr>"
  else
      call REPLWIN_set_pos( pos )
      exe "normal! :0\<cr>\\"ly\/;;\<cr>"
  endif
endfunction

" ===== Send data to the repl
function! REPLWIN_send( rcmd )
  if a:rcmd == ''
    return
  endif

  let p = REPLWIN_get_pos()
  normal! 

  " goto scratch, delete it, put command, write it to the repl
  silent exe "bu!" g:REPLWIN_scratch
  exe "%d"
  normal! 1G

  " tried append() -- doesn't work the way I need it to
  let old_l = @l
  let @l = a:rcmd
  normal! "lP
  let @l = old_l

  exe 'w >>' s:pipe_name

  call REPLWIN_set_pos( p )
endfunction

" ====== Send the current block to the repl
function! REPLWIN_eval_current()
  let p = REPLWIN_get_pos()
  let old_l = @l
$find_vim_block
  let to_eval = @l . ";;"
  let @l = old_l
  call REPLWIN_set_pos( p )
  call REPLWIN_send( to_eval )
endfunction

" ======= Send the selected range to the repl
function! REPLWIN_eval_sel() range
  " save position
  let p = REPLWIN_get_pos()

  " yank current visual block
  let old_l = @l
  '<,'> yank l
  let to_eval = @l
  let @l = old_l

  call REPLWIN_set_pos( p )
  call REPLWIN_send( to_eval )
endfunction



" startup stuff
let g:REPLWIN_scratch = '$scratch_file'
let s:pipe_name = '$pipe'

exe "new" g:REPLWIN_scratch
set bufhidden=hide
set nobuflisted
hide

" Mappings
map <leader>e :call REPLWIN_eval_current()<cr>
map <leader>r :call REPLWIN_eval_sel()<cr>

EOVIM


### Start up screen with a split screen

cat <<EOSCR > $screen_rc
split
screen
focus
resize 10
screen
title $repl
exec ... socat -u PIPE:$pipe EXEC:${repl},sigquit
focus
title "vim"
exec ... vim -c 'so $vim_script' $3

EOSCR

screen -c $screen_rc && rm -rf $temp_dir 

