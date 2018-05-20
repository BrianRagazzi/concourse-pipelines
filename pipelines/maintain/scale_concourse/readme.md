Given an existing concourse cluster and BOSH Director, this presents two jobs; 

* scale-up-concourse - To scale the concourse cluster worker count up by 1
* scale-down-concourse - To scale the concourse cluster worker count down by 1

Be aware that if you are running scale-down-concourse on the same concourse instance it is targetting, that you could get a failure where the worker is being used to attempt to delete itself.
