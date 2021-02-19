
replacement for original nerdtree fs menu

recommended usage:

```
Plugin 'scrooloose/nerdtree'
Plugin 'ZSaberLv0/nerdtree_menu_util'

" optional, auto backup for destructive operations
Plugin 'ZSaberLv0/ZFVimBackup'

" optional, remove some useless builtin menu item to prevent key conflict
Plugin 'ZSaberLv0/nerdtree_fs_menu'
let g:loaded_nerdtree_exec_menuitem = 1
let g:loaded_nerdtree_fs_menu = 1
```

why:

* the default fs menu has many useless item,
    which is easy to have key conflict with your own,
    and there's no way to disable it

