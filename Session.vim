let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
doautoall SessionLoadPre
silent only
silent tabonly
cd ~/dissertation
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
set shortmess+=aoO
badd +301 dissertation.typ
badd +34 template.typ
badd +69 refs.bib
argglobal
%argdel
$argadd dissertation.typ
edit dissertation.typ
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe 'vert 1resize ' . ((&columns * 96 + 96) / 192)
exe 'vert 2resize ' . ((&columns * 95 + 96) / 192)
argglobal
balt refs.bib
setlocal foldmethod=manual
setlocal foldexpr=v:lua.aerial_foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
silent! normal! zE
sil! 8,9fold
sil! 10,11fold
sil! 6,11fold
sil! 16,19fold
sil! 80,81fold
sil! 83,89fold
sil! 91,96fold
sil! 98,102fold
sil! 107,108fold
sil! 110,111fold
sil! 113,117fold
sil! 119,122fold
sil! 132,133fold
sil! 135,138fold
sil! 140,143fold
sil! 145,147fold
sil! 149,151fold
let &fdl = &fdl
let s:l = 301 - ((38 * winheight(0) + 23) / 46)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 301
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("template.typ", ":p")) | buffer template.typ | else | edit template.typ | endif
if &buftype ==# 'terminal'
  silent file template.typ
endif
balt dissertation.typ
setlocal foldmethod=manual
setlocal foldexpr=v:lua.aerial_foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
silent! normal! zE
sil! 12,16fold
sil! 21,24fold
sil! 19,25fold
sil! 9,26fold
sil! 34,37fold
sil! 40,44fold
sil! 51,52fold
sil! 50,53fold
sil! 59,60fold
sil! 61,62fold
sil! 63,64fold
sil! 65,66fold
sil! 69,74fold
sil! 58,75fold
sil! 56,76fold
sil! 79,82fold
sil! 87,89fold
sil! 92,102fold
sil! 107,109fold
sil! 4,112fold
sil! 115,117fold
let &fdl = &fdl
let s:l = 120 - ((41 * winheight(0) + 23) / 46)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 120
normal! 021|
wincmd w
exe 'vert 1resize ' . ((&columns * 96 + 96) / 192)
exe 'vert 2resize ' . ((&columns * 95 + 96) / 192)
tabnext 1
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=20
let &shortmess = s:shortmess_save
let &winminheight = s:save_winminheight
let &winminwidth = s:save_winminwidth
let s:sx = expand("<sfile>:p:r")."x.vim"
if filereadable(s:sx)
  exe "source " . fnameescape(s:sx)
endif
let &g:so = s:so_save | let &g:siso = s:siso_save
set hlsearch
let g:this_session = v:this_session
let g:this_obsession = v:this_session
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
