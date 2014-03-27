0.3.8
=====
* Change ElasticBeanstalk environment name pattern. Stop using sufix hash to make eb environment global unique. (Because ElasticBeanstalk does not require environment has globally uniqe name any more.)
* Add migration logic so that if a ElasticBeanstalk environment with legcy name exists, eb_deployer will automaticly terminate it and replace it with ElasticBeanstalk environment has new name pattern.
