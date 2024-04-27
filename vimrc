" source /etc/vim/vimrc
" Comments in Vimscript start with a `"`.


set nocompatible  " VI compatible mode is disabled so that VIm things work
let mapleader=","


""""""""""""""""""""""""""""""
" Plugins setting
""""""""""""""""""""""""""""""
" ---* call plugins
"   - Vim (Linux/macOS): '~/.vim/plugged'
"   - Vim (Windows): '~/vimfiles/plugged'
"   - Neovim (Linux/macOS/Windows): stdpath('data') . '/plugged'
call plug#begin()
    Plug 'preservim/nerdtree'                       " display directory
    Plug 'ryanoasis/vim-devicons'                   " add file icon in NERDTree
    Plug 'tiagofumo/vim-nerdtree-syntax-highlight'  " highlight file in NERDTree
    Plug 'mhinz/vim-startify'                       " display most recently used file when vim started with no arguments
    Plug 'vim-airline/vim-airline'                  " modify display in bottom status line and head line, display buffer
    Plug 'vim-airline/vim-airline-themes'           " theme for air-line
    Plug 'christoomey/vim-tmux-navigator'           " unify pane navigation in vim and tmux
call plug#end()


" ---* nerdtree
"  keymappings
nnoremap <C-n> :NERDTreeMirror<CR>:NERDTreeFocus<CR>
nnoremap <F3> :NERDTreeToggle<CR>
" If another buffer tries to replace NERDTree, put it in the other window, and bring back NERDTree.
autocmd BufEnter * if bufname('#') =~ 'NERD_tree_\d\+' && bufname('%') !~ 'NERD_tree_\d\+' && winnr('$') > 1 |
    \ let buf=bufnr() | buffer# | execute "normal! \<C-W>w" | execute 'buffer'.buf | endif
" Start NERDTree when Vim starts with a directory argument.
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists('s:std_in') |
    \ execute 'NERDTree' argv()[0] | wincmd p | enew | execute 'cd '.argv()[0] | endif
" Exit Vim if NERDTree is the only window remaining in the only tab.
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
" other settings
let NERDTreeShowBookmarks       = 1     " enable bookmarks
let NERDTreeHighlightCursorline = 1     " highlight current line
let NERDTreeShowLineNumbers     = 1     " display line number
let NERDTreeIgnore = [ '\.pyc$', '\.pyo$', '\.obj$', '\.o$', '\.egg$', '^\.git$', '^\.repo$', '^\.svn$', '^\.hg$' ]  " set ignore file


" ---* startify
" show modified and untracked git file, returns all modified files of the current git repo,
" `2>/dev/null` makes the command fail quietly, so that when we are not in a git repo, the list will be empty
function! s:gitModified()
    let files = systemlist('git ls-files -m 2>/dev/null')
    return map(files, "{'line': v:val, 'path': v:val}")
endfunction
" same as above, but show untracked files, honouring .gitignore
function! s:gitUntracked()
    let files = systemlist('git ls-files -o --exclude-standard 2>/dev/null')
    return map(files, "{'line': v:val, 'path': v:val}")
endfunction
" Read ~/.NERDTreeBookmarks file and takes its second column
function! s:nerdtreeBookmarks()
    let bookmarks = systemlist("cut -d' ' -f 2- ~/.NERDTreeBookmarks")
    let bookmarks = bookmarks[0:-2] " Slices an empty last line
    return map(bookmarks, "{'line': v:val, 'path': v:val}")
endfunction
" make the file we got above shown in startify page
let g:startify_lists = [
        \ { 'type': 'files',     'header': ['   MRU']            },
        \ { 'type': 'dir',       'header': ['   MRU '. getcwd()] },
        \ { 'type': 'sessions',  'header': ['   Sessions']       },
        \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      },
        \ { 'type': function('s:gitModified'),  'header': ['   git modified']},
        \ { 'type': function('s:gitUntracked'), 'header': ['   git untracked']},
        \ { 'type': 'commands',  'header': ['   Commands']       },
        \ { 'type': function('s:nerdtreeBookmarks'), 'header': ['   NERDTree Bookmarks']}
        \ ]


" ---* vim-airline
let g:airline#extensions#whitespace#checks =
  \  [ 'indent', 'trailing', 'mixed-indent-file', 'conflicts' ]  " disable trailing warnings
let g:airline#extensions#tabline#enabled        = 1 " enable tabline
let g:airline#extensions#tabline#buffer_nr_show = 1 " display buffer number
let g:airline#extensions#ale#enabled            = 1 " enable ale integration
let g:airline_theme                             = 'luna'  " bubblegum, violet


""""""""""""""""""""""""""""""
" CUSTOM SHORTCUTS  (LEADER, FN, &c)
""""""""""""""""""""""""""""""
" ---* setting buffer keymappings
" (avoid using new tab if you are not familier with buffer, window and tab in vim)
" close current buffer
nnoremap <silent> <leader>k :bdelete<CR>
" open a new buffer
nnoremap <silent> <leader>o :enew<CR>
" switch buffer
nnoremap <silent> <leader>] :bnext<CR>
nnoremap <silent> <leader>[ :bprevious<CR>
" " <leader>1~9 switch to buffer1~9
" map <leader>1 :b 1<CR>
" map <leader>2 :b 2<CR>
" map <leader>3 :b 3<CR>
" map <leader>4 :b 4<CR>
" map <leader>5 :b 5<CR>
" map <leader>6 :b 6<CR>
" map <leader>7 :b 7<CR>
" map <leader>8 :b 8<CR>
" map <leader>9 :b 9<CR>


" setting window operation
" nnoremap <silent> <Right> :vertical res+2<CR>
" nnoremap <silent> <Left> :vertical res-2<CR>
" nnoremap <silent> <Up> :res+2<CR>
" nnoremap <silent> <Down> :res-2<CR>


""""""""""""""""""""""""""""""
" VIM EDITOR SETTINGS
""""""""""""""""""""""""""""""
" ---* Color Scheme
syntax on	        " enable syntax processing
set shortmess+=I    " Disable the default Vim startup message.


" ---* UI Config
set number		        " show line numbers
set relativenumber		" show relative numbering
set laststatus=2		" Show the status line at the bottom


" By default, Vim doesn't let you hide a buffer (i.e. have a buffer that isn't
" shown in any window) that has unsaved changes. This is to prevent you from
" forgetting about unsaved changes and then quitting e.g. via `:qa!`. We find
" hidden buffers helpful enough to disable this protection. See `:help hidden`
" for more information on this.
set hidden
set noerrorbells visualbell t_vb=	"Disable annoying error noises
set showcmd		    " show command in bottom bar
set cursorline		" highlight current line
filetype indent on	" load filetype-specific indent files
set autoindent
filetype plugin on	" load filetype specific plugin files
set wildmenu		" visual autocomplete for command menu
set showmatch		" highlight matching [{()}]
set mouse+=r		" A necessary evil, mouse support
set splitbelow		" Open new vertical split bottom
set splitright		" Open new horizontal splits right
set linebreak		" Have lines wrap instead of continue off-screen
set scrolloff=12	" Keep cursor in approximately the middle of the screen
set updatetime=100	" Some plugins require fast updatetime
set ttyfast 		" Improve redrawing


" ---* Spaces & Tabs
set tabstop=4		" number of visual spaces per TAB
set softtabstop=4	" number of spaces in tab when editing
set shiftwidth=4	" Insert 4 spaces on a tab
set expandtab		" tabs are spaces, mainly because of python


" ---* Buffers
set hidden		"Allows having hidden buffers(not displayed in any window)


" ---* Sensible stuff
" The backspace key has slightly unintuitive behavior by default. For example,
" by default, you can't backspace before the insertion point set with 'i'.
" This configuration makes backspace behave more reasonably, in that you can
" backspace over anything.
set backspace=indent,eol,start
" Unbind some useless/annoying default key bindings.
" 'Q' in normal mode enters Ex mode. You almost never want this.
nnoremap Q <Nop>
" Unbind for tmux
noremap <C-a> <Nop>
noremap <C-x> <Nop>


" ---* Searching
set incsearch	" search as characters are entered
set hlsearch	" highlight matches
set ignorecase	" Ignore case in searches by default
set smartcase	" But make it case sensitive if an uppercase is entered
" turn off search highlight
nnoremap // :nohlsearch<CR>
set wildignore+=*/.git/*,*/tmp/*,*.swp  " Ignore files for completion


" ---* Undo
set undofile " Maintain undo history between sessions
set undodir=~/.vim/undodir


" ---* auto type mached (){}[]
" inoremap { {}<ESC>i<CR><ESC>V<O
" inoremap ( ()<ESC>i
" inoremap [ []<ESC>i
" inoremap < <><ESC>i
" inoremap <C-[> <ESC>


" Try to prevent bad habits like using the arrow keys for movement. This is
" not the only possible bad habit. For example, holding down the h/j/k/l keys
" for movement, rather than using more efficient movement commands, is also a
" bad habit. The former is enforceable through a .vimrc, while we don't know
" how to prevent the latter.
" ...and in insert mode
inoremap <Left>  <ESC>:echoe "Use h"<CR>
inoremap <Right> <ESC>:echoe "Use l"<CR>
inoremap <Up>    <ESC>:echoe "Use k"<CR>
inoremap <Down>  <ESC>:echoe "Use j"<CR>
" inoremap <Left>  <ESC>i
" inoremap <Right> <ESC>la
" inoremap <Up>    <ESC>ki
" inoremap <Down>  <ESC>ji
