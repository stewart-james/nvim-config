return {
  'seblj/roslyn.nvim',
  opts = {
    exe = {
      'dotnet',
      vim.fs.joinpath(vim.fn.stdpath 'data', 'roslyn', 'Microsoft.CodeAnalysis.LanguageServer.dll'),
    },
  },
}
