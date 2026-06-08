resource "aws_lambda_layer_version" "requests" {
  layer_name          = "${var.name_prefix}-layer-python-requests"
  filename            = "${path.module}/python-requests-layer.zip"
  source_code_hash    = filebase64sha256("${path.module}/python-requests-layer.zip")
  compatible_runtimes = ["python3.11"]
  description         = "requests library for Lambda"
}
