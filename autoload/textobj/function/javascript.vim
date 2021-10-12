" Text objects for functions in javascript.
" Version: 0.2
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

let s:save_cpo = &cpo
set cpo&vim

function! textobj#function#javascript#select(object_type)
  return s:select_{a:object_type}()
endfunction

function! s:select_a()
  let c = v:count1
  let range = 0
  while c
    unlet! r
    let r = s:function_range()
    if type(r) == type(0)
      break
    endif

    call setpos('.', r[0])
    call s:left()

    unlet! range
    let range = r
    let c -= 1
  endwhile

  if type(range) == type([])
    let type = 'v'
    call setpos('.', range[0])
    if col('.') == 1 || getline('.')[:col('.') - 2] =~ '^\s*$'
      call setpos('.', range[1])
      if getline('.')[col('.'):] =~ '^\s*$'
        let type = 'V'
      endif
    endif
    let range = [type] + range
  endif
  return range
endfunction


function! s:select_i()
  let range = s:select_a()
  if type(range) == type(0)
    return 0
  endif

  let type = 'v'

  let endpos = range[2]
  call setpos('.', endpos)

  if s:cursor_char() != '}'
    " Expression closures: function() expr
    let b = s:head
    let e = endpos
  else
    let linewise = 0
    if col('.') == 1 || getline('.')[:col('.') - 2] =~ '^\s*$'
      normal! k$
    let linewise = 1
    else
      call s:left()
    endif
    let e = getpos('.')

    call setpos('.', endpos)
    call s:jump_to_pair()

    if getline('.')[col('.'):] =~ '^\s*$'
      normal! j0
      if linewise
        let type = 'V'
      endif
    else
      normal! l
    endif
    let b = getpos('.')
  endif

  return [type, b, e]
endfunction

function! s:function_range()
  let start = getpos('.')
  " look backward for function definition or fat arrow
  let prev = start
  while search('\v<function>|(\(%(\k|\.\.\.|,|\s)*\)|\k+)\s*\=\>\s*', 'bcW') != 0
    let b = getpos('.')
    if b ==# prev
      break
    endif
    let prev = b

    " go to either the start of the function argument list or right after the fat arrow
    if (search('\v(<async>\s+)?(<function>\s*\k*\s*\(|\=\>\s*)', 'ceW'))
      " if we're on the start of a normal function argument list - skip it
      if s:cursor_char() == '('
        call s:jump_to_pair()
      endif
    endif

    while search('\S', 'W') != 0 && s:cursor_syn() ==# 'Comment'
    endwhile
    if s:cursor_char() == '{'
      call s:jump_to_pair()
    else
      " Expression closures: function() expr
      let s:head = getpos('.') " to inner

      while search('[])}[({,;]', 'W')
        if s:cursor_syn() =~# '\%(Constant\|Comment\)'
          continue
        endif
        let char = s:cursor_char()
        if char =~ '[])},;]'
          break
        elseif char =~ '[[({]'
          call s:jump_to_pair()
        endif
      endwhile

      call search('\S', 'bW')
    endif
    let e = getpos('.')

    if e[1] < start[1] || (e[1] == start[1] && e[2] < start[2])
      call setpos('.', b)
      call s:left()
      continue
    endif
    return [b, e]
  endwhile

  call setpos('.', start)
  
  " handle ES6 class method. back to something like "foo("
  if !search('\v\k+\s*\(', 'bcW')
    return 0
  endif
  let b = getpos('.')
  call s:left()
  " in left side back, syntax have Class identifier
  if s:cursor_syn() !~ 'jsClass'
    return 0
  endif
  " move forward to the end of block
  if !search('(', 'ceW')
    return 0
  endif
  call s:jump_to_pair()
  
  while search('\S', 'W') != 0 && s:cursor_syn() ==# 'Comment'
  endwhile
  if s:cursor_char() != '{'
    return 0
  endif
  call s:jump_to_pair()
  
  let e = getpos('.')
  return [b, e]
endfunction

function! s:jump_to_pair()
  normal %
endfunction

function! s:left()
  if col('.') == 1
    if line('.') != 1
      normal! k$
    endif
  else
    normal! h
  endif
endfunction

function! s:cursor_char()
  return getline('.')[col('.') - 1]
endfunction

function! s:cursor_syn()
  return synIDattr(synIDtrans(synID(line('.'), col('.'), 0)), 'name')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
