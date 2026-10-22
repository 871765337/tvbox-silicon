# Cloud Files review demo

Read-only AList v3 protocol fixture for Apple beta review. It is not an OpenList installation.
The Worker serves deterministic guest listings, a public folder-password exercise and generated
H.264/AAC samples. It has no personal storage, account credentials, uploads, database or write API.
Keep its custom domain active throughout review and the beta. Cloudflare handles network metadata.

Deploy from this folder with `../../website/node_modules/.bin/wrangler deploy`, after checking the
checkout is up to date with origin/main. The website privacy policy documents the app's requests.

Generated media: 30 seconds of FFmpeg `testsrc2` at 640×360/24 fps and a 440 Hz sine wave encoded
as H.264/AAC MP4; a separate 15-second sine wave is encoded as AAC M4A. No external media assets.
`sample-sizes.json` records their sizes for the file metadata and playback proxy.

Test with `node --test worker.test.mjs`. The live AList integration test in CloudFilesTests can use
`TVBOX_ALIST_URL=https://yingxia-review.getmegaportal.com TVBOX_ALIST_FOLDER=/Samples`.
