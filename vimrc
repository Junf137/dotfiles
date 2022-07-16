" source /etc/vim/vimrc
" Comments in Vimscript start with a `"`.


set nocompatible  " VI compatible mode is disabled so that VIm things work
let mapleader=","


" =============================================================================
"   Plugins setting
" =============================================================================
" ---* call plugins
"call plug#begin('~/.vim/plugged')
"    Plug 'preservim/nerdtree'                       " display directory
"    Plug 'ryanoasis/vim-devicons'                   " add file icon in NERDTree
"    Plug 'tiagofumo/vim-nerdtree-syntax-highlight'  " highlight file in NERDTree
"    Plug 'Yggdroot/LeaderF', { 'do': ':LeaderfInstallCExtension' }  " search file, search function
"    Plug 'mhinz/vim-startify'                       " display most recently used file when vim started with no arguments
"    Plug 'Valloric/YouCompleteMe'                   " completion
"    " Plug 'dense-analysis/ale'                       " asynchronous lint engine
"    Plug 'scrooloose/nerdcommenter'                 " shortcut for comment(optional)
"    Plug 'vim-airline/vim-airline'                  " modify display in bottom status line and head line, display buffer
"    Plug 'vim-airline/vim-airline-themes'           " theme for air-line
"    Plug 'yggdroot/indentline'                      " show indent line with nested code layer
"    Plug 'tpope/vim-surround'                       " trick for surround symbol
"call plug#end()


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


" ---* leaderF
" leaderF itself is alreadyvery fast, but you can still install a extention to make it almost 10 times faster.(see more detail in github)
let g:Lf_ShowDevIcons   = 1                                 " Show icons, icons are shown by default
let g:Lf_DevIconsFont   = "DroidSansMono Nerd Font Mono"    " For GUI vim, the icon font can be specify like this, for example
set ambiwidth=double                                        " If needs
let g:Lf_HideHelp        = 1                                " don't show the help in normal mode
let g:Lf_UseCache        = 0
let g:Lf_UseVersionControlTool = 0
let g:Lf_IgnoreCurrentBufferName = 1
" popup mode
let g:Lf_WindowPosition = 'popup'   " open leaderF ina popup window or floating window(gvim)
let g:Lf_PreviewInPopup = 1         " open preview window in popup window(use <Ctrl-pop> again)
let g:Lf_StlSeparator = { 'left': "\ue0b0", 'right': "\ue0b2", 'font': "DejaVu Sans Mono for Powerline" }
let g:Lf_PreviewResult = {'Function': 0, 'BufTag': 0 }
" keymappings
let g:Lf_ShortcutF      = '<C-P>'
" let g:Lf_CommandMap = {'<C-K>': ['<Left>', '<C-K>'], '<C-J>': ['<Right>', '<C-J>']}
noremap <leader>b :<C-U><C-R>=printf("Leaderf buffer %s", "")<CR><CR>
noremap <leader>m :<C-U><C-R>=printf("Leaderf mru %s", "")<CR><CR>
noremap <leader>t :<C-U><C-R>=printf("Leaderf bufTag %s", "")<CR><CR>
noremap <leader>l :<C-U><C-R>=printf("Leaderf line %s", "")<CR><CR>
noremap <C-B> :<C-U><C-R>=printf("Leaderf! rg --current-buffer -e %s ", expand("<cword>"))<CR>
noremap <C-F> :<C-U><C-R>=printf("Leaderf! rg -e %s ", expand("<cword>"))<CR>
" search visually selected text literally
xnoremap gf :<C-U><C-R>=printf("Leaderf! rg -F -e %s ", leaderf#Rg#visual())<CR>
noremap go :<C-U>Leaderf! rg --recall<CR>
" gtags
let g:Lf_GtagsAutoGenerate = 1
let g:GtagsCscope_Quiet = 1
let g:Lf_Gtagslabel = 'native-pygments'
" Show reference to a symbol which has definitions
noremap <leader>r :<C-U><C-R>=printf("Leaderf! gtags --reference %s --auto-jump", expand("<cword>"))<CR><CR>
" Show locations of definitions
noremap <leader>d :<C-U><C-R>=printf("Leaderf! gtags --definition %s --auto-jump", expand("<cword>"))<CR><CR>
" Recall last search. If the result window is closed, reopen it
noremap <leader>fo :<C-U><C-R>=printf("Leaderf! gtags --recall %s", "")<CR><CR>
" Jump to the next result
noremap <leader>n :<C-U><C-R>=printf("Leaderf gtags --next %s", "")<CR><CR>
" Jump to the ptprevious result
noremap <leader>p :<C-U><C-R>=printf("Leaderf gtags --previous %s", "")<CR><CR>


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


" ---* YouCompleteMe
let g:ycm_global_ycm_extra_conf                         = '/home/eric/.vim/plugged/YouCompleteMe/third_party/ycmd/.ycm_extra_conf.py'
let g:ycm_min_num_of_chars_for_completion               = 2 " enable completion when 2 characters are entered
let g:ycm_seed_identifiers_with_syntax                  = 1 " enable completion with syntax keyword
let g:ycm_complete_in_comments                          = 1 " enable completion in comments
let g:ycm_complete_in_strings                           = 1 " enable completion in string
let g:ycm_collect_identifiers_from_tag_files            = 1 " using tags files generated by ctags
let g:ycm_collect_identifiers_from_comments_and_strings = 1 " content in comments and string will be used for completion
let g:ycm_cache_omnifunc                                = 0 " generating match every time, forbidden matching cache
let g:ycm_use_ultisnips_completer                       = 0 " don't search ultisnips for completion, set it to 1 if needed
let g:ycm_show_diagnostics_ui                           = 0 " forbidden syntax checking
" Unbind keys for YouCompleteMe
let g:ycm_key_list_select_completion                    = ['<C-j>', '<TAB>']    " choose next completion ['<TAB>', '<Down>']
let g:ycm_key_list_previous_completion                  = ['<C-k>']             " choose last completion ['<S-TAB>', '<Up>']
let g:ycm_key_list_stop_completion                      = ['<Enter>']           " confirm completion ['<C-y>']


" ---* ale
let g:ale_lint_on_text_changed       = 'normal'                     " check after text changed
let g:ale_lint_on_insert_leave       = 1                            " check after leaving insert mode
let g:ale_sign_column_always         = 1                            " show result dynamicly
let g:ale_sign_error                 = '>>'
let g:ale_sign_warning               = '--'
let g:ale_echo_msg_error_str         = 'E'
let g:ale_echo_msg_warning_str       = 'W'
let g:ale_echo_msg_format            = '[%linter%] %s [%severity%]'
" C 语言配置检查参数
let g:ale_c_gcc_options              = '-Wall -Werror -O2 -std=c11'
let g:ale_c_clang_options            = '-Wall -Werror -O2 -std=c11'
let g:ale_c_cppcheck_options         = ''
" C++ 配置检查参数
let g:ale_cpp_gcc_options            = '-Wall -Werror -O2 -std=c++14'
let g:ale_cpp_clang_options          = '-Wall -Werror -O2 -std=c++14'
let g:ale_cpp_cppcheck_options       = ''
"使用clang对c和c++进行语法检查，对python使用pylint进行语法检查
let g:ale_linters = {
\   'c++': ['clang', 'gcc'],
\   'c': ['clang', 'gcc'],
\   'python': ['pylint'],
\}
" <F9> toggle checking
map <F9> :ALEToggle<CR>
" normal mode, goto next and previous error
nmap ,ak <Plug>(ale_previous_wrap)
nmap ,aj <Plug>(ale_next_wrap)
" check detailed error msg
nmap ,ad :ALEDetail<CR>


" ---* nerdcommenter
" Usage:
" (1) Comment out the current line or text selected in visual mode.
"   [count]<leader>c<space> |NERDCommenterToggle| (recommended)
" (2) Adds comment delimiters to the end of line and goes into insert mode between them. (default in <leader>cA, modified in plugin source code)
"   <leader>ca |NERDCommenterAppend|
filetype plugin on
let g:NERDSpaceDelims            = 1                                    " Add spaces after comment delimiters by default
let g:NERDTrimTrailingWhitespace = 1                                    " Enable trimming of trailing whitespace when uncommenting
let g:NERDCompactSexyComs        = 1                                    " Use compact syntax for prettified multi-line comments
let g:NERDDefaultAlign           = 'left'                               " Align line-wise comment delimiters flush left instead of following code indentation
let g:NERDAltDelims_java         = 1                                    " Set a language to use its alternate delimiters by default
let g:NERDCustomDelimiters       = {'c': {'left': '/*', 'right': '*/'}} " Add your own custom formats or override the defaults
let g:NERDCommentEmptyLines      = 1                                    " Allow commenting and inverting empty lines (useful when commenting a region)
let g:NERDToggleCheckAllLines    = 1                                    " Enable NERDCommenterToggle to check all selected lines is commented or not


" ---* vim-airline
let g:airline#extensions#whitespace#checks =
  \  [ 'indent', 'trailing', 'mixed-indent-file', 'conflicts' ]  " disable trailing warnings
let g:airline#extensions#tabline#enabled        = 1 " enable tabline
let g:airline#extensions#tabline#buffer_nr_show = 1 " display buffer number
let g:airline#extensions#ale#enabled            = 1 " enable ale integration
let g:airline_theme                             = 'luna'  " bubblegum



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
nnoremap <silent> <Right> :vertical res+2<CR>
nnoremap <silent> <Left> :vertical res-2<CR>
nnoremap <silent> <Up> :res+2<CR>
nnoremap <silent> <Down> :res-2<CR>


" ---* vim-surround
"   cs [current surround] [replecement surround], replace surround symbol
"   ds [current surround], delete surround symbol
"   csw [symbol], add surround for a word
"   css [symbol], add surround for a line
nmap csw ysiw
nmap css yss


" ---* indentline
let g:indentLine_char_list = ['|', '¦', '┆', '┊']  " Change Indent Char



" =============================================================================
"   CUSTOM SHORTCUTS  (LEADER, FN, &c)
" =============================================================================
" ---* autocompile with c & c++ & Java & Python language
noremap <F5> :call CompileRunGcc()<CR>
func! CompileRunGcc()
    exec "w"
    if &filetype == 'c'
        exec "!gcc % -o %<"
        exec "!time ./%<"
    elseif &filetype == 'cpp'
        exec "!g++ % -o %<"
        exec "!time ./%<"
    elseif &filetype == 'java'
        exec "!javac %"
        exec "!time java %<"
    elseif &filetype == 'sh'
        :!time bash %
    elseif &filetype == 'python'
        exec "!time python2.7 %"
    elseif &filetype == 'html'
        exec "!firefox % &"
    elseif &filetype == 'go'
        exec "!go build %<"
        exec "!time go run %"
    elseif &filetype == 'mkd'
        exec "!~/.vim/markdown.pl % > %.html &"
        exec "!firefox %.html &"
    endif
endfunc


" ---* shortcut for log print
inoremap <silent>  echo "[Log]: "<ESC>i
nnoremap <silent>  iecho "[Log]: "<ESC>i


" ---* shortcut for Warning print
"inoremap <silent>  echo "[Warring]: "<ESC>i
"nnoremap <silent>  iecho "[Warring]: "<ESC>i


" ---* using vim build-in register as clipboard
" requiring vim-gtk or other version of vim that support build-in rgister
"xnoremap y "*y
"nnoremap y "*y
"xnoremap d "*d
"nnoremap d "*d
"nnoremap p "*p



" =============================================================================
" VIM EDITOR SETTINGS
" =============================================================================
" ---* Color Scheme
syntax on	        " enable syntax processing
set shortmess+=I    " Disable the default Vim startup message.


" ---* UI Config
set number		" show line numbers
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
inoremap { {}<ESC>i<CR><ESC>V<O
inoremap ( ()<ESC>i
inoremap [ []<ESC>i
inoremap < <><ESC>i
inoremap <C-[> <ESC>


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
