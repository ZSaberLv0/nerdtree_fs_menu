
" ============================================================
if !exists("g:NERDTreeAutoDeleteBuffer")
    let g:NERDTreeAutoDeleteBuffer = 0
endif

function! s:setupModule(module, enable, text, key, callback)
    if !exists('g:nfm_' . a:module . '_enable')
        execute 'let g:nfm_' . a:module . '_enable=' . a:enable
    endif
    if !exists('g:nfm_' . a:module . '_text')
        execute 'let g:nfm_' . a:module . '_text="' . a:text . '"'
    endif
    if !exists('g:nfm_' . a:module . '_key')
        execute 'let g:nfm_' . a:module . '_key="' . a:key . '"'
    endif
    if eval('g:nfm_' . a:module . '_enable')
        call NERDTreeAddMenuItem({
                    \ 'text': eval('g:nfm_' . a:module . '_text'),
                    \ 'shortcut': eval('g:nfm_' . a:module . '_key'),
                    \ 'callback': a:callback })
    endif
endfunction

function! s:inputPrompt(action)
    if a:action == "add"
        let title = "Add a childnode"
        let info = "Enter the dir/file name to be created. Dirs end with a '/'"
        let minimal = "Add node:"

    elseif a:action == "copy"
        let title = "Copy the current node"
        let info = "Enter the new path to copy the node to:"
        let minimal = "Copy to:"

    elseif a:action == "delete"
        let title = "Delete the current node"
        let info = "Are you sure you wish to delete the node:"
        let minimal = "Delete?"

    elseif a:action == "deleteNonEmpty"
        let title = "Delete the current node"
        let info =  "STOP! Directory is not empty! To delete, type 'yes'"
        let minimal = "Delete directory?"

    elseif a:action == "move"
        let title = "Rename the current node"
        let info = "Enter the new path for the node:"
        let minimal = "Move to:"
    endif

    if g:NERDTreeMenuController.isMinimal()
        redraw! " Clear the menu
        return minimal . " "
    else
        let divider = "=========================================================="
        return title . "\n" . divider . "\n" . info . "\n"
    end
endfunction

function! s:promptToDelBuffer(bufnum, msg)
    echo a:msg
    if g:NERDTreeAutoDeleteBuffer || nr2char(getchar()) ==# 'y'
        " 1. ensure that all windows which display the just deleted filename
        " now display an empty buffer (so a layout is preserved).
        " Is not it better to close single tabs with this file only ?
        let s:originalTabNumber = tabpagenr()
        let s:originalWindowNumber = winnr()
        " Go to the next buffer in buffer list if at least one extra buffer is listed
        " Otherwise open a new empty buffer
        if v:version >= 800
            let l:listedBufferCount = len(getbufinfo({'buflisted':1}))
        elseif v:version >= 702
            let l:listedBufferCount = len(filter(range(1, bufnr('$')), 'buflisted(v:val)'))
        else
            " Ignore buffer count in this case to make sure we keep the old
            " behavior
            let l:listedBufferCount = 0
        endif
        if l:listedBufferCount > 1
            exec "tabdo windo if winbufnr(0) == " . a:bufnum . " | exec ':bnext! ' | endif"
        else
            exec "tabdo windo if winbufnr(0) == " . a:bufnum . " | exec ':enew! ' | endif"
        endif
        exec "tabnext " . s:originalTabNumber
        exec s:originalWindowNumber . "wincmd w"
        " 3. We don't need a previous buffer anymore
        exec "bwipeout! " . a:bufnum
    endif
endfunction

function! s:renameBuffer(bufNum, newNodeName, isDirectory)
    if a:isDirectory
        let quotedFileName = fnameescape(a:newNodeName . '/' . fnamemodify(bufname(a:bufNum),':t'))
        let editStr = g:NERDTreePath.New(a:newNodeName . '/' . fnamemodify(bufname(a:bufNum),':t')).str({'format': 'Edit'})
    else
        let quotedFileName = fnameescape(a:newNodeName)
        let editStr = g:NERDTreePath.New(a:newNodeName).str({'format': 'Edit'})
    endif
    " 1. ensure that a new buffer is loaded
    exec "badd " . quotedFileName
    " 2. ensure that all windows which display the just deleted filename
    " display a buffer for a new filename.
    let s:originalTabNumber = tabpagenr()
    let s:originalWindowNumber = winnr()
    exec "tabdo windo if winbufnr(0) == " . a:bufNum . " | exec ':e! " . editStr . "' | endif"
    exec "tabnext " . s:originalTabNumber
    exec s:originalWindowNumber . "wincmd w"
    " 3. We don't need a previous buffer anymore
    try
        exec "confirm bwipeout " . a:bufNum
    catch
        " This happens when answering Cancel if confirmation is needed. Do nothing.
    endtry
endfunction


" ============================================================
" addnode
call s:setupModule('addnode', 1, '(a)dd', 'a', 'NERDTreeAddNode')
function! NERDTreeAddNode()
    let curDirNode = g:NERDTreeDirNode.GetSelected()
    let prompt = s:inputPrompt("add")
    let newNodeName = input(prompt, curDirNode.path.str() . g:NERDTreePath.Slash(), "file")

    if newNodeName ==# ''
        call nerdtree#echo("Node Creation Aborted.")
        return
    endif

    try
        let newPath = g:NERDTreePath.Create(newNodeName)
        let parentNode = b:NERDTree.root.findNode(newPath.getParent())

        let newTreeNode = g:NERDTreeFileNode.New(newPath, b:NERDTree)
        " Emptying g:NERDTreeOldSortOrder forces the sort to
        " recalculate the cached sortKey so nodes sort correctly.
        let g:NERDTreeOldSortOrder = []
        if empty(parentNode)
            call b:NERDTree.root.refresh()
            call b:NERDTree.render()
        elseif parentNode.isOpen || !empty(parentNode.children)
            call parentNode.addChild(newTreeNode, 1)
            call NERDTreeRender()
            call newTreeNode.putCursorHere(1, 0)
        endif

        redraw!
    catch /^NERDTree/
        call nerdtree#echoWarning("Node Not Created.")
    endtry
endfunction


" ============================================================
" movenode
call s:setupModule('movenode', 1, '(m)ove', 'm', 'NERDTreeMoveNode')
function! NERDTreeMoveNode()
    let curNode = g:NERDTreeFileNode.GetSelected()
    let prompt = s:inputPrompt("move")
    let newNodePath = input(prompt, curNode.path.str(), "file")

    if newNodePath ==# ''
        call nerdtree#echo("Node Renaming Aborted.")
        return
    endif

    try
        if curNode.path.isDirectory
            let l:openBuffers = filter(range(1,bufnr("$")),'bufexists(v:val) && fnamemodify(bufname(v:val),":p") =~# curNode.path.str() . "/.*"')
        else
            let l:openBuffers = filter(range(1,bufnr("$")),'bufexists(v:val) && fnamemodify(bufname(v:val),":p") ==# curNode.path.str()')
        endif

        call curNode.rename(newNodePath)
        " Emptying g:NERDTreeOldSortOrder forces the sort to
        " recalculate the cached sortKey so nodes sort correctly.
        let g:NERDTreeOldSortOrder = []
        call b:NERDTree.root.refresh()
        call NERDTreeRender()

        " If the file node is open, or files under the directory node are
        " open, ask the user if they want to replace the file(s) with the
        " renamed files.
        if !empty(l:openBuffers)
            if curNode.path.isDirectory
                echo "\nDirectory renamed.\n\nFiles with the old directory name are open in buffers " . join(l:openBuffers, ', ') . ". Replace these buffers with the new files? (yN)"
            else
                echo "\nFile renamed.\n\nThe old file is open in buffer " . l:openBuffers[0] . ". Replace this buffer with the new file? (yN)"
            endif
            if g:NERDTreeAutoDeleteBuffer || nr2char(getchar()) ==# 'y'
                for bufNum in l:openBuffers
                    call s:renameBuffer(bufNum, newNodePath, curNode.path.isDirectory)
                endfor
            endif
        endif

        call curNode.putCursorHere(1, 0)

        redraw!
    catch /^NERDTree/
        call nerdtree#echoWarning("Node Not Renamed.")
    endtry
endfunction


" ============================================================
" deletenode
call s:setupModule('deletenode', 1, '(d)elete', 'd', 'NERDTreeDeleteNode')
function! NERDTreeDeleteNode()
    let l:shellslash = &shellslash
    let &shellslash = 0
    let currentNode = g:NERDTreeFileNode.GetSelected()
    let confirmed = 0

    if currentNode.path.isDirectory && ((currentNode.isOpen && currentNode.getChildCount() > 0) ||
                                      \ (len(currentNode._glob('*', 1)) > 0))
        let prompt = s:inputPrompt("deleteNonEmpty") . currentNode.path.str() . ": "
        let choice = input(prompt)
        let confirmed = choice ==# 'yes'
    else
        let prompt = s:inputPrompt("delete") . currentNode.path.str() . " (yN): "
        echo prompt
        let choice = nr2char(getchar())
        let confirmed = choice ==# 'y'
    endif

    if confirmed
        try
            call currentNode.delete()
            call NERDTreeRender()

            "if the node is open in a buffer, ask the user if they want to
            "close that buffer
            let bufnum = bufnr("^".currentNode.path.str()."$")
            if buflisted(bufnum)
                let prompt = "\nNode deleted.\n\nThe file is open in buffer ". bufnum . (bufwinnr(bufnum) ==# -1 ? " (hidden)" : "") .". Delete this buffer? (yN)"
                call s:promptToDelBuffer(bufnum, prompt)
            endif

            redraw!
        catch /^NERDTree/
            call nerdtree#echoWarning("Could not remove node")
        endtry
    else
        call nerdtree#echo("delete aborted")
    endif
    let &shellslash = l:shellslash
endfunction


" ============================================================
" copynode
if g:NERDTreePath.CopyingSupported()
call s:setupModule('copynode', 1, '(c)opy', 'c', 'NERDTreeCopyNode')
endif
function! NERDTreeCopyNode()
    let l:shellslash = &shellslash
    let &shellslash = 0
    let currentNode = g:NERDTreeFileNode.GetSelected()
    let prompt = s:inputPrompt("copy")
    let newNodePath = input(prompt, currentNode.path.str(), "file")

    if newNodePath != ""
        "strip trailing slash
        let newNodePath = substitute(newNodePath, '\/$', '', '')

        let confirmed = 1
        if currentNode.path.copyingWillOverwrite(newNodePath)
            call nerdtree#echo("Warning: copying may overwrite files! Continue? (yN)")
            let choice = nr2char(getchar())
            let confirmed = choice ==# 'y'
        endif

        if confirmed
            try
                let newNode = currentNode.copy(newNodePath)
                " Emptying g:NERDTreeOldSortOrder forces the sort to
                " recalculate the cached sortKey so nodes sort correctly.
                let g:NERDTreeOldSortOrder = []
                if empty(newNode)
                    call b:NERDTree.root.refresh()
                    call b:NERDTree.render()
                else
                    call NERDTreeRender()
                    call newNode.putCursorHere(0, 0)
                endif
            catch /^NERDTree/
                call nerdtree#echoWarning("Could not copy node")
            endtry
        endif
    else
        call nerdtree#echo("Copy aborted.")
    endif
    let &shellslash = l:shellslash
    redraw!
endfunction

