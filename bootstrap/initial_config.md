# Some simple bootstraing to keep in mind

## Initial Git config

    git config --global core.editor vim
    git config --global user.name "Marian Posaceanu"
    git config --global user.email contact@marianposaceanu.com
    git config --global core.autocrlf true
    git config --global github.user dakull

## Add a git submodule

    git add submodule https://github.com/chriskempson/base16-vim.git .vim/bundle/base16-vim

## Remove a git submodule

    Delete the relevant section from the .gitmodules file.

    Stage the .gitmodules changes git add .gitmodules

    Delete the relevant section from .git/config.

    Run git rm --cached path_to_submodule (no trailing slash).

    Run rm -rf .git/modules/path_to_submodule

    Commit

    Delete the now untracked submodule files

    rm -rf path_to_submodule

### Credits

- [submodule delete](http://stackoverflow.com/questions/1260748/how-do-i-remove-a-git-submodule)


