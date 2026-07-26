# Transcript — Customer onboarding portal, discovery workshop

[00:00:00] Elena: Okay, we're recording — thanks everyone for blocking the full hour. This is our discovery workshop for the new customer onboarding portal.

[00:00:12] Elena: Quick round of who's here — Raj, you're sponsoring this from the sales side, right?

[00:00:20] Raj: That's right. I'll be speaking mostly for sales and account management.

[00:00:29] Tom: And I'm ops — I run the team that actually processes onboarding today, so I'm here for the pain points.

[00:00:38] Dana: I'm engineering. I'm mostly here to sanity-check feasibility as we go, flag anything that's a bigger lift than it sounds.

[00:00:47] Elena: Perfect, that's our four for the hour.

[00:00:55] Elena: Since we've got the full hour, I want to get through a real agenda instead of free-forming it. Three things: self-service intake, the legacy data situation, and access control.

[00:01:05] Raj: Works for me. We've got a lot to cover, so let's not linger too long on any one thing.

[00:01:15] Elena: Agreed. I'll keep us moving and park anything that's not core.

[00:01:26] Tom: Sounds good. I've got until the top of the hour, then I'm back-to-back.

[00:01:38] Dana: Same, I'm free for the full block.

[00:01:52] Elena: Great. Let's do a level-set first — Raj, big picture, what are we actually trying to fix with this portal?

[00:02:08] Raj: Broadly, getting new customers set up without my team hand-holding every single one. But let's get into the specifics rather than me talking in generalities.

[00:02:20] Elena: Let's start with the big one — the self-service piece. Raj, walk me through what onboarding a new customer looks like today.

[00:02:28] Raj: Right now it's painfully manual. A new client signs the contract, and then someone on Tom's team literally emails them a PDF form, gets it back, and keys everything into our system by hand.

[00:02:40] Tom: Yeah, and it's usually me or one other person doing it, so it bottlenecks fast when we onboard more than a couple of clients in a week.

[00:02:50] Elena: Okay, that's the pain. What's the fix you have in mind?

[00:03:00] Raj: Let me lay it out properly.

[00:03:10] Raj: The client signs, gets an email with a link, and does the rest themselves — no PDF, no re-typing on our end.

[00:03:20] Dana: So the account gets created from whatever they enter directly, no manual step at all?

[00:03:30] Raj: So what we want is a self-service portal. The new client logs in, fills in their own company details, uploads whatever documents we need, and it just lands in our system without my team retyping anything.

[00:03:42] Dana: That's doable. Is there an approval step, or does whatever they submit go live immediately?

[00:03:52] Raj: Good question.

[00:04:00] Tom: We definitely don't want it going live with zero checks — I've seen enough typos and mismatched company names to want a human eye on it.

[00:04:10] Raj: There should be a review step. Tom's team approves before an account is active. They just shouldn't have to do data entry anymore. Review, not retype.

[00:04:20] Tom: That I'd love. Approving is fine — it's the typing that kills us.

[00:04:29] Elena: Great, so self-service intake with a review-before-active gate. That's captured.

[00:04:38] Dana: On the technical side, that's a standard pattern — public intake form, private admin queue for the review. Nothing exotic.

[00:04:48] Raj: Good, glad it's not a huge lift.

[00:04:56] Elena: Anything else on the intake flow itself before we move on?

[00:05:05] Raj: One more thing, actually.

[00:05:13] Elena: Go ahead.

[00:05:20] Raj: One thing while we're on it — the portal should look like us, not like a generic form. Our branding, our colors.

[00:05:29] Elena: Noted, though that's more of a design-polish detail than a requirement — I'll keep it in the notes but I won't make a story out of it unless it grows teeth.

[00:05:40] Raj: Fair.

[00:05:50] Tom: While we're on wishlist items — can the form save partway through? Some of our clients are slow to gather documents.

[00:06:03] Dana: Save-and-resume is easy enough if we're already building a form with an account behind it. I wouldn't call that a separate ask, more an implementation detail of the same self-service flow.

[00:06:16] Elena: Agreed, that folds into the same story rather than being its own thing.

[00:06:30] Raj: Makes sense.

[00:06:46] Elena: Okay. Self-service intake is locked — Raj, Tom, sound right to both of you?

[00:07:04] Raj: Sounds right.

[00:07:24] Tom: Agreed, that's the one I most wanted out of today.

[00:07:50] Elena: Good. I want to leave time for the other two items, so let's take stock — anything on self-service we haven't said out loud yet?

[00:08:20] Dana: Not from my side — feasibility's fine on everything discussed.

[00:09:00] Elena: Great, self-service piece is closed out. Let's spend a few minutes on how onboarding's actually been going before we get into the trickier stuff.

[00:09:15] Tom: Sure. Volume's been up the last two months — probably averaging four or five new accounts a week now.

[00:09:28] Elena: That's up from what, two or three?

[00:09:37] Tom: Yeah, more like two a week back in the spring. It's climbing.

[00:09:50] Raj: Sales has been closing faster than I expected, honestly.

[00:10:03] Dana: Good problem to have, I guess.

[00:10:12] Tom: Good problem, but it means the manual keying we talked about is eating more of my week than it used to.

[00:10:26] Elena: Right, that's exactly the pain we just captured — the PDF-and-retype process.

[00:10:38] Tom: Exactly that. Same process, just more of it lately.

[00:10:50] Raj: Which is a good argument for shipping the portal sooner rather than later.

[00:11:02] Elena: Noted, no argument here. How's the team holding up otherwise?

[00:11:14] Tom: We're managing. I moved one person from support onto onboarding two days a week to cover it.

[00:11:28] Dana: Is that sustainable if volume keeps climbing?

[00:11:40] Tom: Not really, not past another month or two at this rate.

[00:11:53] Elena: All the more reason this is the right project at the right time.

[00:12:05] Raj: Agreed. I don't think we need to relitigate the fix, just flagging the pressure's real.

[00:12:18] Elena: Understood. Anything on the sales side worth flagging while we're recapping?

[00:12:31] Raj: Not really — pipeline's healthy, nothing unusual. Just more of the same manual handoff to Tom's team once a deal closes.

[00:12:44] Dana: And from engineering's side, nothing new to report — we haven't started build yet, obviously, this is discovery.

[00:12:57] Elena: Right, that's the whole point of today.

[00:13:10] Tom: Honestly, most of what I'd flag is just more of the same — same PDF process, just handling more volume than a few months ago.

[00:13:24] Elena: Right, that's the pain we already captured, just intensifying.

[00:13:38] Raj: Which is exactly why I think the timing on this project is good.

[00:13:50] Dana: Agreed, better to build it now than wait until the volume's even worse.

[00:14:02] Elena: Good, so nothing new, just more urgency behind what we already have.

[00:14:15] Tom: Right.

[00:14:28] Elena: Anything else operational before we move to scheduling and ownership?

[00:14:40] Raj: Not from me.

[00:14:53] Dana: Nothing from me either.

[00:15:05] Tom: I'm good.

[00:15:17] Elena: Okay. Let's talk about who owns what going forward and when we regroup, since that's its own can of worms.

[00:15:29] Raj: Fair warning, I have opinions on scheduling.

[00:15:42] Elena: Noted. Let's get into it.

[00:15:55] Tom: Ready when you are.

[00:16:08] Dana: Same here.

[00:16:20] Elena: Okay — ownership. Raj, is this your project to drive, or does it sit with Tom's team once we're past discovery?

[00:16:33] Raj: I'll own it through build, then Tom's team owns it operationally once it's live.

[00:16:46] Tom: That tracks — I'll want a seat in build reviews, but day-to-day ownership after launch, sure.

[00:16:58] Elena: Good, that's clean. Dana, who's actually going to build this on your side?

[00:17:11] Dana: I'll pull in one more engineer once we scope it properly — probably not me solo, this is bigger than a one-person build.

[00:17:24] Elena: Makes sense. Any sense of timeline once discovery wraps?

[00:17:37] Dana: Depends what we land on today, honestly. I don't want to commit to a date before we've even finished the requirements.

[00:17:50] Elena: Fair, I won't pin you down today. Let's talk about when we regroup instead.

[00:18:03] Raj: I'd like a check-in before we go too far into build, not just a big-bang reveal at the end.

[00:18:16] Elena: Agreed, that's good practice anyway. Two weeks out?

[00:18:29] Dana: Two weeks feels early if I haven't even staffed it yet. Three would be safer.

[00:18:42] Tom: Three works for me too — I've got a company all-hands in the middle of week two anyway.

[00:18:55] Elena: Three weeks it is. I'll get something on calendars this week.

[00:19:08] Raj: Appreciate it.

[00:19:20] Elena: Anyone traveling or out in the next month I should know about, so we don't schedule around it?

[00:19:33] Tom: I'm out the second week of next month, just so you know.

[00:19:46] Dana: Nothing on my end.

[00:19:58] Raj: I'm around, but heads up I've got a board update due right before that window, so I might be distracted that week.

[00:20:11] Elena: Noted, I'll try to land the check-in outside that week if I can.

[00:20:24] Elena: On format — do we want a full workshop again, or just a shorter async check-in?

[00:20:37] Raj: Shorter's fine if there's nothing controversial to decide.

[00:20:50] Dana: I'd rather have a live slot in case I need to walk through tradeoffs, even a short one.

[00:21:03] Elena: Okay, thirty minutes, live, three weeks out. I'll send an invite.

[00:21:16] Tom: Works for me.

[00:21:29] Elena: Who should be in the room for that one — same four, or does it widen?

[00:21:42] Raj: Same four for now. If we need someone else pulled in for a specific question, we can loop them in separately.

[00:21:55] Dana: Agreed, keep it tight.

[00:22:08] Elena: Good. I'll also share notes from today by end of week so everyone can flag anything I got wrong.

[00:22:21] Raj: Perfect, appreciate that.

[00:22:34] Elena: One more logistics thing — do we need sign-off from anyone not in this room before build starts?

[00:22:47] Raj: My VP will want a quick look, but that's a formality at this point, she's already bought in.

[00:23:00] Tom: Nothing on my side needs sign-off beyond what's in this room.

[00:23:13] Dana: Same, engineering doesn't need anything extra once Raj and Tom are aligned.

[00:23:26] Elena: Great, that simplifies things. Okay, logistics is sorted — three-week check-in, notes by Friday, same group.

[00:23:39] Raj: Sounds good. What's next on the agenda?

[00:23:52] Elena: Legacy data and access control, but before we dive back into the meaty stuff, let's take a breather — anyone need water, coffee?

[00:24:05] Tom: I'm good for now.

[00:24:15] Dana: Same.

[00:24:24] Raj: Actually, since we're pausing a second — can I circle back to the branding thing for one more second? I keep thinking about it.

[00:24:36] Elena: Sure, quick version.

[00:24:47] Raj: I just don't want us to ship something that looks like a generic SaaS template. It matters more than it sounds like.

[00:25:00] Elena: I hear you, and I'm not dismissing it — it's parked, not dropped. It's just not shaped as a concrete requirement yet, more a quality bar.

[00:25:14] Dana: If it helps, whatever we build will use a normal component library, so custom colors and a logo are cheap to apply later. It's not a structural decision either way.

[00:25:27] Raj: Good to know. Then I'm fine leaving it parked, as long as it doesn't get forgotten entirely.

[00:25:40] Elena: It's in my notes, I promise. Won't get lost.

[00:25:53] Tom: For what it's worth, our current PDF form has our logo on it at least, so it's not like we're starting from zero on brand presence.

[00:26:06] Raj: True, small mercies.

[00:26:19] Dana: Speaking of the current PDF, is that thing even still being updated, or is it the same file from years ago?

[00:26:32] Tom: Same file from years ago, more or less. I think I fixed a typo on it once.

[00:26:45] Raj: Classic.

[00:26:58] Elena: Okay, we've thoroughly closed the loop on branding. Moving on — actually, let's do a quick stretch break, thirty seconds, then keep going.

[00:27:11] Tom: Ha, sure.

[00:27:40] Dana: Back.

[00:27:48] Raj: Back.

[00:27:55] Elena: Okay. Before the next chunk, how's everyone's week been, since we've barely talked about anything but work for half an hour?

[00:28:08] Tom: Busy, but fine. Kid's got a school thing tonight I'm rushing to.

[00:28:21] Elena: Go us for finishing on time, then.

[00:28:34] Dana: I'm mostly heads-down on an unrelated project until this one kicks off, so this is a nice change of pace.

[00:28:47] Raj: Same boat, this is honestly the most interesting meeting on my calendar this week.

[00:29:00] Elena: High bar, I'll take it. Okay, let's get back into it.

[00:29:13] Raj: Ready.

[00:29:26] Elena: Quick recap so we don't lose the thread — we've locked self-service intake, we've parked the branding note, and we've talked ownership and scheduling.

[00:29:39] Tom: That's right.

[00:29:52] Dana: Matches my notes.

[00:30:05] Elena: Two things left — the legacy data situation and access control. Raj, you flagged legacy data earlier as connected to the bigger picture.

[00:30:18] Raj: Right, I want to get to that, but let me set it up properly instead of rushing it like I did before.

[00:30:31] Elena: Take your time, we've got the room for it.

[00:30:44] Tom: This is the one I'm curious about, honestly — I know it's messy on your end.

[00:30:57] Raj: It's messy, yeah. Let me walk through the history a bit first so the ask makes sense.

[00:31:10] Elena: Go for it.

[00:31:23] Raj: So, we've been around for about six years now. In the early days, everything was tracked in spreadsheets because we were tiny.

[00:31:36] Tom: I remember those days. I think I was employee number four.

[00:31:49] Raj: Right, and back then a spreadsheet was totally fine — we had maybe twenty customers total.

[00:32:02] Dana: Sure, that's normal for that stage.

[00:32:15] Raj: As we grew, nobody ever formally moved off the spreadsheet. It just kept getting bigger and split into a few different files over the years.

[00:32:28] Tom: Different people owned different versions at different points too, if I remember right.

[00:32:41] Raj: Exactly, so there's a 2021 version, a 2022 version with slightly different columns, and whatever we're using now.

[00:32:54] Dana: Classic spreadsheet sprawl. I've seen this exact pattern at other companies.

[00:33:07] Elena: How many customers are we talking about total, roughly, across all those files?

[00:33:20] Raj: I'd have to check exactly, but it's grown a lot since those first twenty.

[00:33:33] Tom: It's a lot. I don't touch those files myself, but I hear people complain about them.

[00:33:46] Raj: Yeah, whoever needs a customer's history has to know which file year to open, which is its own small nightmare.

[00:33:59] Dana: Are the files at least all still accessible, or has anything been lost over the years?

[00:34:12] Raj: As far as I know everything still exists, just scattered. Nobody's deleted anything, thankfully.

[00:34:25] Elena: Good, that's the important part — nothing's actually lost.

[00:34:38] Tom: Small mercies again.

[00:34:51] Raj: Right. Anyway, this has been sitting in the back of my mind since we first talked about doing the portal.

[00:35:04] Elena: Makes sense that it would come up — new front door, old back rooms.

[00:35:17] Dana: That's a good way to put it.

[00:35:30] Raj: It is exactly that. New customers will go through the shiny new thing, and the old ones are still living in Excel.

[00:35:43] Tom: Which feels a little backwards once you say it out loud.

[00:35:56] Raj: It does. That's kind of why I brought it up earlier and then didn't finish the thought.

[00:36:09] Elena: I remember, we parked it right before the last break — legacy data connected to the bigger picture.

[00:36:22] Raj: Right, that one. Let me actually get to it properly this time instead of trailing off again.

[00:36:35] Dana: Take your time, we're not going anywhere.

[00:36:48] Elena: We've got a good chunk of the hour left, don't rush on our account.

[00:37:01] Tom: Yeah, this is clearly the thing you've been sitting on, might as well get it all the way out.

[00:37:14] Raj: Fair, okay. Let me set the scene properly.

[00:37:27] Elena: Go ahead.

[00:37:40] Raj: When we launch this portal, I don't want to leave the old accounts behind, sitting in spreadsheets while everyone else is in the new system.

[00:37:53] Dana: Makes sense — so you want the historical accounts brought into whatever we build, not just new signups going forward.

[00:38:06] Raj: Exactly that.

[00:38:19] Elena: Okay, so this is more than reminiscing — there's an actual ask here.

[00:38:32] Raj: There is. Let me say it plainly.

[00:38:45] Tom: Please do, I've been waiting for the actual ask for five minutes now.

[00:38:58] Raj: Fair. Here it is.

[00:39:11] Raj: We've got maybe five thousand existing customer records sitting in Excel files from the last few years — those need to come into the new system somehow, not just the new signups.

[00:39:24] Dana: So a bulk import of the legacy records, on top of the live self-service flow. Are those spreadsheets consistent — same columns each time?

[00:39:37] Raj: Honestly, no. That's the messy part. Some are from 2021, a different format than the 2023 ones.

[00:39:50] Tom: That tracks with what you were saying about different owners over the years.

[00:40:03] Raj: Let me come back to that — I want to think about the exact columns before I commit to anything.

[00:40:16] Elena: Sure, we can hold the details. Is the core ask clear enough to write down, even without the exact columns yet?

[00:40:29] Raj: Yes — bulk import the legacy records so nothing gets left behind when we launch. The exact fields are the open question, not the ask itself.

[00:40:42] Dana: That's a clean enough ask to work with. I'll want the details before we scope it, obviously, but the shape is clear.

[00:40:55] Tom: Same, I get the shape of it.

[00:41:08] Elena: Good. Let's hold the import specifics for after a quick break, then — this is a good natural stopping point.

[00:41:21] Raj: Works for me, my brain could use two minutes anyway.

[00:41:34] Tom: Seconded.

[00:41:47] Elena: Okay, let's do it — two minutes, then back to finish the legacy data piece plus access control.

[00:42:00] Tom: Perfect. Back in two.

[00:42:03] Elena: Back in two.

[00:44:20] Elena: Okay, we're back. Before I get to access control, Raj — you wanted to come back to the legacy data import.

[00:44:33] Raj: Yeah, thanks for holding it.

[00:44:41] Elena: Go ahead.

[00:44:52] Raj: So, on those old spreadsheets — the format's inconsistent, but they all have the core stuff: company name, primary contact email, signup date, and plan tier. It's the extra columns that vary file to file.

[00:45:05] Dana: So if we import on those four common fields and flag the rest for manual cleanup, would that work? I'm trying to avoid building a custom mapper for every historical format.

[00:45:18] Raj: That works for me. Get the five thousand in on the core fields, and my team can patch the odd ones by hand afterward. The whole point is not re-keying five thousand accounts from scratch.

[00:45:31] Tom: As long as the import tells me which rows failed instead of silently dropping them, I'm happy. I've been burned by a silent import before.

[00:45:44] Dana: Yeah, we'd give you an error report — row number and what was wrong. Bad email, missing plan tier, that sort of thing.

[00:45:57] Raj: That's exactly what I'd want. Okay, good — that one's settled.

[00:46:10] Elena: Great. So: bulk import of the legacy spreadsheets, core four fields, with a validation report for the rows that don't make it.

[00:46:23] Tom: Agreed.

[00:46:36] Dana: Works for me.

[00:46:49] Elena: Anything else on the legacy import before we close it out?

[00:47:02] Tom: Just to double check — this covers all the old accounts, not a subset?

[00:47:15] Raj: All of them, yeah. No reason to leave some behind.

[00:47:28] Tom: Good, that's what I was hoping to hear.

[00:47:41] Raj: I'll get Dana sample exports from a couple of the years so she can see how messy it actually is.

[00:47:54] Dana: Appreciated, that'll help a lot when we actually scope the build.

[00:48:07] Elena: Good, one clean requirement. Anything else on process before we lock it?

[00:48:20] Dana: One process question — once we've got the error report, who actually reviews and fixes the failed rows? You, Tom, or someone on Raj's side?

[00:48:33] Raj: Good question. Probably my team, since we know the historical accounts best.

[00:48:46] Tom: Fine by me, as long as it's not silently my team's job by default.

[00:48:59] Raj: No, we'll own the cleanup. That's fair, it's our mess.

[00:49:12] Dana: Works for me. I'll design the error report so it's easy to hand off, not just a raw log dump.

[00:49:25] Raj: Appreciated.

[00:49:38] Elena: Timeline-wise, does the import happen before launch or after?

[00:49:51] Dana: Before, ideally — so day one of the new system already has the full customer base, not just new signups trickling in.

[00:50:04] Raj: Agreed, before launch. Otherwise it's confusing having two populations for a while.

[00:50:17] Elena: Now — access control. Tom, this one was mostly your ask.

[00:50:30] Tom: Right. Once clients are self-serving, I don't want every one of my team members able to see and approve everything.

[00:50:43] Tom: Support folks should see client data read-only, but only leads should be able to approve a new account as active.

[00:50:56] Dana: So role-based access — at least two roles to start: a read-only support role and an approver/lead role?

[00:51:09] Tom: Exactly two, to start. We can add more later, but that split covers the pain today.

[00:51:22] Raj: Agreed — keep it to two roles for v1, don't over-engineer it.

[00:51:35] Elena: Perfect. So, two roles: read-only support, and approver/lead who can activate accounts.

[00:51:48] Tom: That's it.

[00:52:01] Dana: On the build side, two roles is simple — I was worried you'd ask for something more granular, like per-account permissions.

[00:52:14] Tom: No, that's overkill for us. Two roles covers it.

[00:52:27] Raj: Agreed, let's not gold-plate it.

[00:52:40] Elena: Any edge cases we should think about now, or is two roles genuinely enough?

[00:52:53] Tom: One thing — what happens if a support person needs to temporarily cover for a lead who's out?

[00:53:06] Raj: Can we just... give that person the lead role temporarily? Doesn't need to be automated.

[00:53:19] Dana: Sure, a manual role change by an admin covers that. Doesn't need a special workflow.

[00:53:32] Tom: That's fine, that's rare enough to handle manually.

[00:53:45] Elena: Good, so two roles, manual reassignment for coverage, nothing fancier needed.

[00:53:58] Raj: Agreed.

[00:54:11] Dana: Agreed, that's buildable as-is.

[00:54:24] Tom: Agreed too. That's everything I wanted from this session.

[00:54:37] Elena: I think that covers everything from today — self-service intake, the legacy import, and role-based access.

[00:54:50] Elena: Quick read-back: self-service portal with a review gate, bulk import of the legacy spreadsheets on the core fields with a validation report, and two roles — read-only support and approver/lead.

[00:55:03] Raj: That's exactly right.

[00:55:16] Tom: Matches what I've got.

[00:55:29] Dana: Same here, nothing missing.

[00:55:42] Elena: Perfect. Thanks, all — good use of the full hour. Notes out by Friday.

[00:55:55] Tom: Thanks, everyone.
