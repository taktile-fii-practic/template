locals {
  source_files = fileset(var.source_path, "{src,functions}/**/*.ts")
  source_hash = sha256(join(",", sort([
    for f in local.source_files : filemd5("${var.source_path}/${f}")
  ])))
  package_hash = filemd5("${var.source_path}/package-lock.json")
  build_dir    = "${var.source_path}/dist"
}

resource "null_resource" "lambda_build" {
  triggers = {
    source_hash  = local.source_hash
    package_hash = local.package_hash
  }

  provisioner "local-exec" {
    working_dir = var.source_path
    command     = <<-EOT
      set -e
      npm ci --prefer-offline

      mkdir -p dist/api dist/delete-worker dist/stream-processor dist/notification

      npx esbuild functions/api.ts \
        --bundle --platform=node --target=es2022 \
        --outfile=dist/api/api.js \
        --external:'@aws-sdk/*' --minify --sourcemap

      npx esbuild functions/delete-worker.ts \
        --bundle --platform=node --target=es2022 \
        --outfile=dist/delete-worker/delete-worker.js \
        --external:'@aws-sdk/*' --minify --sourcemap

      npx esbuild functions/stream-processor.ts \
        --bundle --platform=node --target=es2022 \
        --outfile=dist/stream-processor/stream-processor.js \
        --external:'@aws-sdk/*' --minify --sourcemap

      npx esbuild functions/notification.ts \
        --bundle --platform=node --target=es2022 \
        --outfile=dist/notification/notification.js \
        --external:'@aws-sdk/*' --minify --sourcemap

      cd dist/api && zip -r ../api.zip . && cd ../..
      cd dist/delete-worker && zip -r ../delete-worker.zip . && cd ../..
      cd dist/stream-processor && zip -r ../stream-processor.zip . && cd ../..
      cd dist/notification && zip -r ../notification.zip . && cd ../..
    EOT
  }
}
