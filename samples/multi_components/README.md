Simple Sinatra deployment with both web and work tier as components. Samples sinatra app is from http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/RelatedResources.html

usage:

* Setup an EC2 keypair
* Rename application name in the config/eb_deployer to some uniq name
* AWS_EC2_KEY_NAME=<your-key-name> eb_deployer -p ruby-sample.zip
