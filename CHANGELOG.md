0.4.3
=====
* Backoff and retry when AWS::ElasticBeanstalk::Errors::Throttling happens during polling events

0.4.2
=====
* Allow provding different deploy strategy for different components.

0.4.1
=====
* Remove options for delete all environments ("-d --all"), because it is too destructive and not recoverable.
* Experimental support for multiple components deployment.

0.4.0
====
* revert back all changes from 0.3.8 to 0.3.9. Elasticbeanstalk haven't relex the real unique constain. The actually contrain is you can not have environment name cross different application

0.3.9
====
* Fix hang problem introduced in 0.3.8 when migrating old ElasticBeanstalk environment.
* Fix issue #13 (Deployment via S3 object broken since 0.3.7)

0.3.8
=====
* Change ElasticBeanstalk environment name pattern. Stop using sufix hash to make eb environment global unique. (Because ElasticBeanstalk does not require environment has globally uniqe name any more.)
* Add migration logic so that if a ElasticBeanstalk environment with legcy name exists, eb_deployer will automaticly terminate it and replace it with ElasticBeanstalk environment has new name pattern.
