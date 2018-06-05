I use a batch file like this:

set pl=UpgradeTile-MySQL
fly -t dev dp -p %pl%
fly -t dev sp -p %pl% -c pipeline.yml -l params-prod.yml -l params-mysql.yml -l params-pcf6.yml -l params-thur-0300.yml
fly -t dev up -p %pl%


params-ert.yml contains:
product_name: elastic-runtime
product_version: ^2\.1\..*$
product_identifier: cf
product_glob: "cf-*.pivotal"  #exclude small-footprint version
