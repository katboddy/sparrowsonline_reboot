---
title: "Distributed Systems are Choices and Compromises"
date: "2026-04-22"
summary: "Can I Have My Cookie and Eat it Too?"
slug: "distributed-systems"
image: "/static/assets/images/distro.jpg"
---

## Distributed Systems are Choices and Compromises

Distributed systems are about compromises: you always end up at those forks on the road and no matter which you take you will be a little unhappy. And this is ok, as long as you manage the unhappiness and you are quite sure that the portions of unhappiness served on the other fork are relatively bigger or more unpalatable.

For those reasons it's often safe and reasonable to not distribute if you don't have to. Your home Star Wars collection might not necessarily benefit from a multi-replica database, and you probably won't have to geo-distribute your garage shop until you actually move out of that garage. Also, the hard drives are getting bigger and sharding is not as much fun as you think.

Yet there are some systems that are inherently distributed: email, WhatsApp. Actually, any kind of messenger would be somewhat sad if executed on only one machine, unless you talk to yourself and your alter ego is really entertaining.

As applications grow and become more complex and specialized, there are more advantages and uses for distributed systems:

- Fault tolerance (don't keep all your servers in one basket!)
- Scalability, elasticity (both up- and down-)
- Latency
- Legal complaince for data residence laws
- Specialized hardware (different for memory heavy, different for computation heavy workloads)

This of course comes with added complexity as every part of the system can now fail by itself as well as connections between those parts.

Once you move out of that garage and your software out of your laptop, one of the biggest choices you need to make is cloud vs on-prem (sometimes it's hybrid). Self hosting is a bigger investment up-front, but might cost you less down the road. On the other hand, if you pivot and decide to become a musician what are you going to do with a rack of servers? If you choose cloud, which cloud provider?

As you're diving into system design, you have to make even more choices:

- go with IaaS, PaaS, or FaaS
- what tech to use? build or buy
- monolith vs microservices
- databases
- programming languages
- availability vs consistency
- instrument in house or pay

Some of those choices have lasting consequences and cannot be easily reverted, while the others can be changed more easily. It's good to be cautious with your design, but the vast amount of choices can sometimes lead to absolute paralysis.

I like to start small. Having the comfort of not being a corporation, I can just build it, deploy it, and if I hate it, nuke it and build something new. This is not something I could do as a big business, but building modular makes sense. Not falling in love with your tech is important too. You might love or hate Kubernetes, but the philosophy of treating your infrastructure (and software) like cattle, not pets, is key. If everything is loosely coupled, easily replaceable, and doesn't have a special place in your heart, it can be seamlessly upgraded without affecting the other parts of the system.
