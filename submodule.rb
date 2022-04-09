MODULES = <<~MOD
  https://github.com/ervandew/supertab
  https://github.com/tpope/vim-surround
  https://github.com/tpope/vim-markdown
  https://github.com/tpope/vim-commentary
  https://github.com/godlygeek/tabular
  https://github.com/jelera/vim-javascript-syntax
  https://github.com/bling/vim-airline
  https://github.com/airblade/vim-rooter
  https://github.com/mileszs/ack.vim
  https://github.com/tpope/vim-endwise
  https://github.com/tpope/vim-repeat
  https://github.com/vim-airline/vim-airline-themes
  https://github.com/junegunn/fzf.vim
  https://github.com/altercation/vim-colors-solarized
  https://github.com/scrooloose/nerdtree
  https://github.com/crusoexia/vim-monokai
  https://github.com/zhaocai/GoldenView.Vim
MOD

MODULES.split("\n").each do |module_git_path|
  module_vim_path = ".vim/pack/bundles/start/#{module_git_path.split("/").last}"
  puts `git submodule add #{module_git_path} #{module_vim_path}`
end

# [submodule ".vim/pack/bundles/start/supertab"]
# 	path = .vim/pack/bundles/start/supertab
# 	url = https://github.com/ervandew/supertab
# [submodule ".vim/pack/bundles/start/vim-surround"]
# 	path = .vim/pack/bundles/start/vim-surround
# 	url = https://github.com/tpope/vim-surround.git
# [submodule ".vim/pack/bundles/start/vim-markdown"]
# 	path = .vim/pack/bundles/start/vim-markdown
# 	url = https://github.com/tpope/vim-markdown.git
# [submodule ".vim/pack/bundles/start/vim-commentary"]
# 	path = .vim/pack/bundles/start/vim-commentary
# 	url = https://github.com/tpope/vim-commentary
# [submodule ".vim/pack/bundles/start/vim-tabular"]
# 	path = .vim/pack/bundles/start/vim-tabular
# 	url = https://github.com/godlygeek/tabular.git
# [submodule ".vim/pack/bundles/start/vim-javascript-syntax"]
# 	path = .vim/pack/bundles/start/vim-javascript-syntax
# 	url = https://github.com/jelera/vim-javascript-syntax
# [submodule ".vim/pack/bundles/start/vim-airline"]
# 	path = .vim/pack/bundles/start/vim-airline
# 	url = https://github.com/bling/vim-airline
# [submodule ".vim/pack/bundles/start/vim-rooter"]
# 	path = .vim/pack/bundles/start/vim-rooter
# 	url = https://github.com/airblade/vim-rooter.git
# [submodule ".vim/pack/bundles/start/vim-ack"]
# 	path = .vim/pack/bundles/start/vim-ack
# 	url = https://github.com/mileszs/ack.vim.git
# [submodule ".vim/pack/bundles/start/vim-endwise"]
# 	path = .vim/pack/bundles/start/vim-endwise
# 	url = https://github.com/tpope/vim-endwise.git
# [submodule ".vim/pack/bundles/start/vim-repeat"]
# 	path = .vim/pack/bundles/start/vim-repeat
# 	url = https://github.com/tpope/vim-repeat
# [submodule ".vim/pack/bundles/start/vim-airline-themes"]
# 	path = .vim/pack/bundles/start/vim-airline-themes
# 	url = https://github.com/vim-airline/vim-airline-themes
# [submodule ".vim/pack/bundles/start/vim-fzf"]
# 	path = .vim/pack/bundles/start/vim-fzf
# 	url = https://github.com/junegunn/fzf.vim.git
# [submodule ".vim/pack/bundles/start/vim-colors-solarized"]
# 	path = .vim/pack/bundles/start/vim-colors-solarized
# 	url = https://github.com/altercation/vim-colors-solarized
# [submodule ".vim/pack/bundles/start/vim-nerdtree"]
# 	path = .vim/pack/bundles/start/vim-nerdtree
# 	url = https://github.com/scrooloose/nerdtree.git
# [submodule ".vim/pack/bundles/start/vim-monokai"]
# 	path = .vim/pack/bundles/start/vim-monokai
# 	url = https://github.com/crusoexia/vim-monokai.git
# [submodule ".vim/pack/bundles/start/vim-goldenview"]
# 	path = .vim/pack/bundles/start/vim-goldenview
# 	url = https://github.com/zhaocai/GoldenView.Vim.git
