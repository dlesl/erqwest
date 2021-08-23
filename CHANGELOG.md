# Changelog

Only major and breaking changes are listed

## Unreleased
- Unrecognised options now raise an exception
- Streaming request and response bodies
  - Breaking change: async message format
- Tokio runtime controlled from erlang
  - Breaking change: `erqwest` application now needs to be started before use
- Support for cancelling requests
- Gzip support
- Cookies support

## 0.0.2 - 2021-08-02
- Proxy support
- Follow redirects is now on by default (consistent with reqwest's default)

## 0.0.1 - 2021-07-31
- Initial release

