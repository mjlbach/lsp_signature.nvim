# Installation

With packer:

```lua
local install_path = vim.fn.stdpath 'data' .. '/site/pack/packer/start/packer.nvim'

if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
  vim.fn.execute('!git clone https://github.com/wbthomason/packer.nvim ' .. install_path)
end

vim.cmd [[
  augroup Packer
    autocmd!
    autocmd BufWritePost init.lua PackerCompile
  augroup end
]]

local use = require('packer').use
require('packer').startup(function()
  use 'neovim/nvim-lspconfig'
  use 'mjlbach/lsp-signature.nvim'
end)
```

# Usage
```lua
local on_attach = function(client, bufnr)
  require('lsp_signature').attach(client, bufnr)
end

require('lspconfig').pyright.setup {
  on_attach = on_attach
}
```
