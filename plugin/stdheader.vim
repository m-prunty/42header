" Remove its autocommands
augroup stdheader
        autocmd!
augroup END

" Remove its command
silent! delcommand Stdheader

" Remove its mapping (F1)
silent! nunmap <F1>

let s:asciiart = [
			\"        :::      ::::::::",
			\"      :+:      :+:    :+:",
			\"    +:+ +:+         +:+  ",
			\"  +#+  +:+       +#+     ",
			\"+#+#+#+#+#+   +#+        ",
			\"     #+#    #+#          ",
			\"    ###   ########.fr    "
			\]

let s:start		= '/*'
let s:end		= '*/'
let s:fill		= '*'
let s:length	= 80
let s:margin	= 5

let s:types		= {
			\'\.c$\|\.h$\|\.cc$\|\.hh$\|\.cpp$\|\.hpp$\|\.tpp$\|\.ipp$\|\.cxx$\|\.go$\|\.rs$\|\.php$\|\.java$\|\.kt$\|\.kts$':
			\['/*', '*/', '*'],
			\'\.htm$\|\.html$\|\.xml$':
			\['<!--', '-->', '*'],
			\'\.js$\|\.ts$':
			\['//', '//', '*'],
			\'\.tex$':
			\['%', '%', '*'],
			\'\.ml$\|\.mli$\|\.mll$\|\.mly$':
			\['(*', '*)', '*'],
			\'\.vim$\|\vimrc$':
			\['"', '"', '*'],
			\'\.el$\|\emacs$\|\.asm$':
			\[';', ';', '*'],
			\'\.f90$\|\.f95$\|\.f03$\|\.f$\|\.for$':
			\['!', '!', '/'],
			\'\.lua$':
			\['--', '--', '-'],
			\'\.py$':
			\['#', '#', '*']
			\}

function! s:filetype()
	let l:f = s:filename()

	let s:start	= '#'
	let s:end	= '#'
	let s:fill	= '*'

        if &filetype ==# 'python' || l:f =~ '\.py$'
                let s:length = 79
        endif
	
	for type in keys(s:types)
		if l:f =~ type
			let s:start	= s:types[type][0]
			let s:end	= s:types[type][1]
			let s:fill	= s:types[type][2]
		endif
	endfor

endfunction

function! s:ascii(n)
	return s:asciiart[a:n - 3]
endfunction

function! s:textline(left, right)
	let l:left = strpart(a:left, 0, s:length - s:margin * 2 - strlen(a:right))

	let l:spaces = s:length - s:margin * 2 - strlen(l:left) - strlen(a:right)
	if l:spaces < 0
		let l:spaces = 0
	endif

	return s:start . repeat(' ', s:margin - strlen(s:start)) . l:left . repeat(' ', l:spaces) . a:right . repeat(' ', s:margin - strlen(s:end)) . s:end
endfunction

function! s:line(n)
	if a:n == 1 || a:n == 11 " top and bottom line
		return s:start . ' ' . repeat(s:fill, s:length - strlen(s:start) - strlen(s:end) - 2) . ' ' . s:end
	elseif a:n == 2 || a:n == 10 " blank line
		return s:textline('', '')
	elseif a:n == 3 || a:n == 5 || a:n == 7 " empty with ascii
		return s:textline('', s:ascii(a:n))
	elseif a:n == 4 " filename
		return s:textline(s:filename(), s:ascii(a:n))
	elseif a:n == 6 " author
		return s:textline("By: " . s:user() . " <" . s:mail() . ">", s:ascii(a:n))
	elseif a:n == 8 " created
		return s:textline("Created: " . s:date() . " by " . s:user(), s:ascii(a:n))
	elseif a:n == 9 " updated
		return s:textline("Updated: " . s:date() . " by " . s:user(), s:ascii(a:n))
	endif
endfunction

function! s:user()
	if exists('g:user42')
		return g:user42
	endif
	let l:user = $USER
	if strlen(l:user) == 0
		let l:user = "marvin"
	endif
	return l:user
endfunction

function! s:mail()
	if exists('g:mail42')
		return g:mail42
	endif
	let l:mail = $MAIL
	if strlen(l:mail) == 0
		let l:mail = "marvin@42.fr"
	endif
	return l:mail
endfunction

function! s:filename()
	let l:filename = expand("%:t")
	if strlen(l:filename) == 0
		let l:filename = "< new >"
	endif
	return l:filename
endfunction

function! s:date()
	return strftime("%Y/%m/%d %H:%M:%S")
endfunction

function! s:insert_python_prelude()
	if s:filename() !~ '\.py$'
		return
	endif

	" Insert in reverse order (append(0) pushes down)
	if get(g:, 'stdheader_pyencoding',1)
		call append(0, '# -*- coding: utf-8 -*-')
	endif

	if get(g:, 'stdheader_pyshebang', 1)
		let l:interp = get(g:, 'stdheader_python_interpreter', 'python3')
		call append(0, '#!/usr/bin/env ' . l:interp)
	endif
endfunction

function! s:insert()
	let l:line = 11

	" empty line after header
	call append(0, "")

	" loop over lines
	while l:line > 0
		call append(0, s:line(l:line))
		let l:line = l:line - 1
	endwhile
	call s:insert_python_prelude()
endfunction

function! s:is_updated_line(lnum)
	return getline(a:lnum) =~#
		\ '^' . escape(s:start, '/*#') .
		\ repeat(' ', s:margin - strlen(s:start)) .
		\ 'Updated: '
endfunction

function! s:find_updated_line()
	let l:max = min([line('$'), 20]) " header never exceeds this
	for lnum in range(1, l:max)
		if s:is_updated_line(lnum)
			return lnum
		endif
	endfor
	return -1
endfunction

function! s:update()
	call s:filetype()

	let l:uline = s:find_updated_line()
	if l:uline < 0
		return 1
	endif

	if &mod && s:not_rebasing()
		call setline(l:uline, s:line(9))   " reuse formatting
		call setline(l:uline - 5, s:line(4)) " filename line
	endif

	return 0
endfunction

function! s:stdheader()
	if s:update()
		call s:insert()
	endif
endfunction

function! s:fix_merge_conflict()
	call s:filetype()
	let l:checkline = s:start . repeat(' ', s:margin - strlen(s:start)) . "Updated: "

	" fix conflict on 'Updated:' line
	if getline(9) =~ "<<<<<<<" && getline(11) =~ "=======" && getline(13) =~ ">>>>>>>" && getline(10) =~ l:checkline
		let l:line = 9
		while l:line < 12
			call setline(l:line, s:line(l:line))
			let l:line = l:line + 1
		endwhile
		echo "42header conflicts automatically resolved!"
	exe ":12,15d"

	" fix conflict on both 'Created:' and 'Updated:' (unlikely, but useful in case)
	elseif getline(8) =~ "<<<<<<<" && getline(11) =~ "=======" && getline(14) =~ ">>>>>>>" && getline(10) =~ l:checkline
		let l:line = 8
		while l:line < 12
			call setline(l:line, s:line(l:line))
			let l:line = l:line + 1
		endwhile
		echo "42header conflicts automatically resolved!"
	exe ":12,16d"
	endif
endfunction

function! s:not_rebasing()
	if system("ls `git rev-parse --git-dir 2>/dev/null` | grep rebase | wc -l")
		return 0
	endif
	return 1
endfunction

" Bind command and shortcut

command! Stdheader call s:stdheader ()
map <F1> :Stdheader<CR>

command! -nargs=1 StdheaderPyEncoding
	\ let g:stdheader_pyencoding = <args>
command! -nargs=1 StdheaderPyShebang
	\ let g:stdheader_pyshebang = <args>

augroup stdheader
	autocmd!
	autocmd BufWritePre * call s:update ()
	autocmd BufReadPost * call s:fix_merge_conflict ()
augroup END
