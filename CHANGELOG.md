0.4.6
====
* Make elasticbeanstalk event polling robust against clock shifting problem.

0.4.5
====
* Rails 3+ support: Rails Generator to install default configurations with
	Postgres RDS resource and everything need for blue-green
	deployment
* Add ability to tag beanstalk environment (from @pmcfadden)

0.4.4
=====
* Fix S3 upload on Windows.
* Experimental support for "inactve_settings" options, which can be used to automatically scale down the inactive environment.
* Update default solution stack name to latest supported JAVA stack.
* Validate solution_stack option before creating environment and list available solution_stacks if not valid.

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
