# cfssl-aws
This container will fetch a CA certificate and key from S3, along with a config file for [CFSSL](https://github.com/cloudflare/cfssl). The S3 objects to retrieve are set using environment variables:

<dl>
  <dt><code>CFSSL_CONFIG</code></dt><dd>Path to CFSSL config file (here’s <a href="https://github.com/cloudflare/cfssl/blob/master/doc/api.txt#L445-L478">an example</a>… hopefully the documentation will improve.)</dd>
  <dt><code>CA_CERT</code></dt><dd>S3 path to the PEM-encoded CA certificate</dd>
  <dt><code>CA_KEY</code></dt><dd>S3 path to the PEM-encoded decrypted private key</dd>
</dl>

All S3 paths are passed to the [AWS CLI tool](http://docs.aws.amazon.com/cli/latest/reference/s3/index.html), so format them accordingly.

Additional `cfssl serve` arguments can be passed as the `CMD` of the running container. I typically include 

    -port 22299
    -address 0.0.0.0

to expose the utility on port 22299 and bind to the first available network interface.

### Example: `docker run`

    docker run --name cfssl-aws -d \
      -p 22299:22299 \
      -e CA_CERT=s3://bucket/aws-cert.pem \
      -e CA_KEY=s3://bucket/aws-key.pem \
      -e CFSSL_CONFIG=s3://bucket/config.json \
      -v /home/vagrant/.aws:/opt/dwolla/.aws:ro \
      bpholt/cfssl-s3:latest \
        -port=22299 \
        -address=0.0.0.0

### Example: AWS EC2 Container Service Task Definition

    {
      "family": "cfssl",
      "containerDefinitions": [
        {
          "name": "cfssl",
          "image": "bpholt/cfssl-s3:latest",
          "cpu": 128,
          "memory": 48,
          "essential": true,
          "command": [
            "-port 22299 -address 0.0.0.0"
          ],
          "environment": [
            {
              "name": "CFSSL_CONFIG",
              "value": "s3://bucket/config.json"
            },
            {
              "name": "CA_CERT",
              "value": "s3://bucket/aws-cert.pem"
            },
            {
              "name": "CA_KEY",
              "value": "s3://bucket/aws-key.pem"
            }
          ],
          "portMappings": [
            {
              "hostPort": 0,
              "containerPort": 22299,
              "protocol": "tcp"
            }
          ],
          "entryPoint": [],
          "links": [],
          "mountPoints": [],
          "volumesFrom": []
        }
      ],
      "volumes": []
    }
