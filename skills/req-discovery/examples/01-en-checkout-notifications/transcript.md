# Transcript — Checkout notifications sync

[00:00:00] Priya: Okay, I think everyone's here — Marcus, Jordan, thanks for hopping on. Let's just get into it, we don't have a ton of time today.

[00:00:14] Marcus: Yeah, no worries, I've got till the top of the hour then I've got the... the infra sync thing.

[00:00:21] Priya: Perfect, this should be quick-ish. So I pulled the checkout funnel numbers again this week and, um, we're still seeing this cliff right at the payment step. Like a pretty big one.

[00:00:38] Jordan: Yeah I can back that up from the support side, we get a lot of "I tried to pay and nothing happened" tickets.

[00:00:45] Priya: Right, and I dug into a few of those session replays yesterday — actually, sorry, two days ago — and here's the thing. If a card gets declined right now, the customer just... sees an error and that's it, nobody follows up. There's no email, nothing. They just bounce.

[00:01:10] Marcus: Huh. I mean technically the API does return a decline reason, we're just not doing anything with it downstream.

[00:01:19] Priya: Exactly. So what I'd want is — when a payment fails at checkout, the customer gets an email. Doesn't have to be fancy, just "hey your payment didn't go through, here's why, click here to retry."

[00:01:35] Jordan: That would honestly cut down a good chunk of our ticket volume too.

[00:01:39] Marcus: Makes sense. We already have transactional email set up for order confirmations so it's not a new pipe, just a new trigger really.

[00:01:52] Priya: Good, good. Oh — quick tangent, is anyone else doing the compliance webinar thing on Thursday? I keep meaning to sign up.

[00:02:00] Jordan: I signed up, I'll send you the link after this.

[00:02:03] Priya: Cool, thanks. Okay, back to it. So that's one thing. Jordan, you mentioned tickets — is it mostly the payment failure ones, or is there other stuff piling up too?

[00:02:15] Jordan: There's a second bucket actually, and it's a big one — "where is my order." People pay, and then they just... don't hear anything until it shows up on their doorstep. So they ping support asking if it even shipped.

[00:02:31] Marcus: We do have shipped_at on the order record already, from the carrier webhook.

[00:02:36] Jordan: Right, so the data's there, we're just not telling anyone.

[00:02:40] Priya: So it sounds like — once an order actually ships, the customer should get pinged. Text message probably, more than email, people notice texts faster for "your stuff is coming."

[00:02:54] Jordan: Yeah, SMS makes sense for that one, that's usually a "get excited, it's coming" moment more than a "read carefully" moment.

[00:03:02] Marcus: Okay, that one's a bit more work since we don't have SMS wired up yet at all, but conceptually sure.

[00:03:10] Priya: Fair, that's fine, doesn't need to be this sprint. I just want it captured so it doesn't get lost.

[00:03:16] Jordan: Agreed, it comes up in like every retro of support tickets, it's not going away.

[00:03:22] Priya: Cool. I think that's actually everything I wanted to cover today, that was fast. Anything else before we drop?

[00:03:29] Marcus: Nope, I'm good, heading to the infra thing now.

[00:03:32] Priya: Great, thanks both.
