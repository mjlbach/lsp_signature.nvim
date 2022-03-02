local M = {}

local lsp = vim.lsp
local api = vim.api

local triggers_by_buf = {}
local state_by_buf = {}

local function generate_active_signature_help_autocmd(bufnr, client_id)
  vim.cmd(string.format('augroup signature_help_%d_%d', client_id, bufnr))
  vim.cmd('au!')
  vim.cmd(string.format(
    "autocmd InsertCharPre,CursorMoved,CursorMovedI <buffer=%d> lua require'signature_help_2'._ActiveSignatureEvent(%s)",
    bufnr,
    client_id
  ))
  vim.cmd('augroup end')
end

local function generate_signature_help_autocmd(bufnr, client_id)
  vim.cmd(string.format('augroup signature_help_%d_%d', client_id, bufnr))
  vim.cmd('au!')
  vim.cmd(string.format(
    "autocmd InsertCharPre <buffer=%d> lua require'signature_help_2'._TriggerCharEvent(%s)",
    bufnr,
    client_id
  ))
  vim.cmd('augroup end')
end


local function cleanup_state(client_id, bufnr)
  if not state_by_buf[client_id] or not state_by_buf[client_id][bufnr] then
    return
  end
  local signature_window = state_by_buf[client_id][bufnr].winnr
  if signature_window then
    vim.api.nvim_win_close(signature_window, true)
  end
  state_by_buf[client_id][bufnr] = nil
  generate_signature_help_autocmd(bufnr, client_id)
end

local function signature_help_handler(_, result, ctx, config)
  config = config or {}
  config.focus_id = ctx.method
  -- config.close_events = {"CursorMoved", "CursorMovedI"}
  config.close_events = {}

  -- When use `autocmd CompleteDone <silent><buffer> lua vim.lsp.buf.signature_help()` to call signatureHelp handler
  -- If the completion item doesn't have signatures It will make noise. Change to use `print` that can use `<silent>` to ignore
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not state_by_buf[client.id] then
    state_by_buf[client.id] = {}
  end

  if not (result and result.signatures and result.signatures[1]) then
    if config.silent ~= true then
      print('No signature help available')
    end
    cleanup_state(client.id, ctx.bufnr)
    return
  end

  local triggers = client.resolved_capabilities.signature_help_trigger_characters
  local ft = api.nvim_buf_get_option(ctx.bufnr, 'filetype')
  local lines, hl = vim.lsp.util.convert_signature_help_to_markdown_lines(result, ft, triggers)
  lines = vim.lsp.util.trim_empty_lines(lines)

  if vim.tbl_isempty(lines) then
    if config.silent ~= true then
      print('No signature help available')
    end
    cleanup_state(client.id, ctx.bufnr)
    return
  end

  local fbuf
  local fwin

  if not state_by_buf[client.id][ctx.bufnr] then
    fbuf, fwin = vim.lsp.util.open_floating_preview(lines, "markdown", config)
    state_by_buf[client.id][ctx.bufnr] = {
      winnr = fwin,
      bufnr = fbuf,
    }
    generate_active_signature_help_autocmd(ctx.bufnr, client.id)
  else
    fwin = state_by_buf[client.id][ctx.bufnr].winnr
    fbuf = state_by_buf[client.id][ctx.bufnr].bufnr
  end

  if hl then
    api.nvim_buf_add_highlight(fbuf, -1, "LspSignatureActiveParameter", 0, unpack(hl))
  end
  return fbuf, fwin
end

local function signature_help_request()
  local params = lsp.util.make_position_params()
  lsp.buf_request(0, 'textDocument/signatureHelp', params, function(err, result, ctx, config)
    local conf = config and vim.deepcopy(config) or {}
    conf.focusable = false
    signature_help_handler(err, result, ctx, conf)
  end)
end


function M._TriggerCharEvent()
  local char = api.nvim_get_vvar('char')
  local triggers = triggers_by_buf[api.nvim_get_current_buf()] or {}
  for _, entry in pairs(triggers) do
    local chars, fn = unpack(entry)
    if vim.tbl_contains(chars, char) then
      vim.schedule(fn)
      return
    end
  end
end

function M._ActiveSignatureEvent()
  vim.schedule(signature_help_request)
end

function M.attach(client, bufnr)
  local triggers = triggers_by_buf[bufnr]
  if not triggers then
    triggers = {}
    triggers_by_buf[bufnr] = triggers
  end
  local signature_triggers = client.resolved_capabilities.signature_help_trigger_characters
  if signature_triggers and #signature_triggers > 0 then
    table.insert(triggers, { signature_triggers, signature_help_request })
  end

  generate_signature_help_autocmd(bufnr, client.id)
end

return M
