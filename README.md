# Site-to-Site IPsec Tunnel

We use Libreswan for the userspace, because we're on Fedora, so largely follow [_Configuring a VPN with IPsec_](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/securing_networks/configuring-a-vpn-with-ipsec_securing-networks).

Libreswan uses NSS and there's no obvious way to set up a pair of servers in tantem while sharing their public keys with each other, so we do a bit of manual SSHing.

First deploy the two servers (`left` and `right`) with `terraform apply`. Then SSH into both and become root.

## Left

```
# ipsec showhostkey --left --ckaid $(ipsec showhostkey --list | cut -d " " -f 7)
    # rsakey AwEAAZ+tf
	leftrsasigkey=0sAwEAAZ+tfqA11Teh1uEEX6lxVzj42a+z8ab6q1z6mFsgs6piC9GSciG6kET7UVP+I7XMvK0xIsr+QIMdZaXpX4f9YSccNK6RklsE8ipXpK+inlhOKS1O3xEoFjwy5xO9Q2oifWzQAIg8t0OKZOkHxT2FHsgV1UnVls/MW5L9WTOJ82Xtg8XeQMUrEc4yt7lOSA/5jC1F5/yUhg7/qxIszQDRMarwgtOE/SKOpc/eS05du6eB/cDB8nIrRmfXWpBSCRqYkgoAR9X72EMVdLl9dFFKmggg5SWLO0MzsUv96GENUEiAUjrNHQhmfDOiFCP6mnuXPLQWHLKAXSsydOYJCPWtxwAuWTwcE/Rfbk/UjKMCHBg6gVJSn9kD3AMQMvcUmiMdvG2C+C2OovtJYEof6XRLuPOAjMqj8ceX0cnofDUbUeS4wKl8gSRski4lrd9j+xfe0JFRysLRlTIJKHRzJlskjrL8i372nNipMcOsA7oKTzxdoX2U+IpYnDO+PU5FYy0+hinvZBA+WywkgiRIA8+ZCZIlrYHh5fowCxcguzRuDqfi2qFqh5nFwYxjB8X5Q3/ShC6zATaPTWSnpASpWTTlOo36vy1PCoZl/NRo9/d0fQ5MvkZJ4PrGQnuli+e8xdTIrSrysJTjXPlwlYQtK2lC1i9Bc/9M77Vm9AiX
```

## Right

```
# ipsec showhostkey --right --ckaid $(ipsec showhostkey --list | cut -d " " -f 7)
	# rsakey AwEAAaeaj
	rightrsasigkey=0sAwEAAaeajY9ablap/X59zrMNFVVjcw7X9J48fDAiNSu5yF7hp7i2NwkL5QeY/Anfnco9dWW3UGuEW1yXBsHse2mQwXjZyQksV5hcJG95ufzyEl7WGlIXbf0wQ8EXBcGYtmRzjdEJc09Bxty/6VqOqBaWt1HRGkTS38g4mgKdEuSpgL+Jsv0NYuHb3RyKrh+OG4RDYwzomx7LGgES2LuBoeY5kdk94AlkGZLIOH0xuELH5HFJSmZv2LO+wzMLj28wP303BEvPOKjRRskA/aZza2Lr/jOPYF8vfNziXC2r/9GowhiU8hWvaV4NorIiBXSzHcm597JCCY3o74VaNARwKpkSEk1cBDk0yGPtpZAWI1z+dsl0YQNQrwWz6ohyaPZpqXCeVOELM3T5ExRWBmaPbgpWSk+bZRPNqsRx5fECGZ7fwjEy+XFiBkR/9KPEEmmFiRmby7D3LXQubLY9DSIJIK0nux6pzvH5usJA3ws4cLJ4lz8G2ePvVXZTOAQdBqJQb5Q09Y/Vv9x1L61+ID5B4mM4n/zhDmdIxeL1MXluAu3znOEF6EtIc3WYZeZBQEXpjCdXdL9AvYbA6wh4xUBpgJY8tRbMtliNvC6zUw==
```

## Both

We set configuration data in [`/etc/ipsec.d/site_to_site.conf`](data/site_to_site.conf).

For the configuration file, get the servers' private IP addresses from `aws_instance.{left,right}.private_ip` and their respective subnets from `aws_subnet.{left,right}.cidr_block` (also in the Terraform output). Add them to the configuration file.

Take the above values for `leftrsakey` and `rightrsakey` and add them to the configuration file.

Then restart the service on both machines.

Test that the tunnel is up with
```
# ipsec show
10.0.1.0/24 <=> 10.0.0.0/24 using reqid 16389
10.0.1.92/32 <=> 10.0.0.91/32 using reqid 16393
```
and e.g.
```
# ipsec show 10.0.0.90
10.0.1.0/24 <=> 10.0.0.0/24 using reqid 16389
```
(picking a random IP address from the 10.0.0.0/24 subnet).
