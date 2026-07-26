# Transcript — Release planning sync

[00:00:00] Sam: Alright, last thing on the agenda — deploy timing for the checkout notifications work. Marcus, where's that at?

[00:00:09] Marcus: It's basically done, QA signed off yesterday. I think we could ship it Friday afternoon, honestly. Get it out before the weekend, and then marketing's push on Monday already has it live.

[00:00:24] Priya: Friday afternoon works for me on the marketing side, that lines up nicely with the Monday email blast.

[00:00:31] Sam: Yeah, let's pencil in Friday afternoon then, say 3pm.

[00:00:36] Marcus: Cool, 3pm Friday, I'll put it on the calendar.

[00:00:41] Priya: Oh, before we move on — did the accessibility audit thing get scheduled yet? I saw it on the roadmap doc but no date.

[00:00:49] Sam: Not yet, I'll follow up with that team separately, don't want to derail this meeting.

[00:00:54] Priya: Fair, just flagging it.

[00:00:57] Marcus: Actually, hold on, going back to the deploy — I want to walk that back a bit.

[00:01:03] Sam: Go for it.

[00:01:04] Marcus: So Friday afternoon means if something breaks, we're finding out Friday night or over the weekend, and on-call is just me and one other person right now, nobody else really knows this code path yet.

[00:01:18] Sam: That's a fair point actually, we don't have great weekend coverage on payments-adjacent stuff.

[00:01:24] Marcus: Right, and this touches the checkout flow, so if it's broken, that's revenue-affecting, not just "annoying bug."

[00:01:32] Priya: Okay, that's a good point, I don't love that risk either honestly. What's the alternative?

[00:01:38] Marcus: I'd rather do it first thing Monday morning, like 10am, when the whole team's online and we can watch it for a couple hours before anything ramps up.

[00:01:48] Sam: Monday 10am, so it ships before your marketing email goes out, right?

[00:01:53] Priya: Let me check... yeah, the blast doesn't go out till 1pm, so 10am gives us a buffer either way.

[00:02:00] Sam: Okay, I'm convinced. Let's kill the Friday slot and lock Monday 10am instead. Marcus, can you update the release calendar?

[00:02:08] Marcus: Yep, doing that right after this call.

[00:02:11] Sam: Great, thanks everyone, that's all I had.
