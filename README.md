# replicated-demo

Example repo for creating required manifests for a Replicated release.
This uses a single `umbrella` chart that contains a number of dependency charts,
and then install them all as a single helm release.

For the example, just run the following commands from the root of the repo:
* `helm package -u charts/umbrella -d tmp_release/manifests`
* `./replicated-releases/prep-replicated-release.sh umbrella 0.1.0`
