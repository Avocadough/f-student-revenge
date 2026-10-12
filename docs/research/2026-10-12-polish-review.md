# Independent polish review — 12 October 2026

## Scope and evidence

First-pass review recorded at 20:56 ICT. This is **not final acceptance**. The root and UI implementer were already repairing the layout problems below when this review was written.

- Read current diffs in `Scripts/student_player.gd`, `Scripts/school_enemy.gd`, `Scripts/teacher_ally.gd`, and the four integration lines in `Scripts/campus_stage.gd`; read `tools/test_motion_polish.gd`, `tools/test_teacher_companion.gd`, and relevant existing motion fixtures.
- Visually inspected the generated `.dream-loop/target.png`; all six `evidence/2026-10-12-polish/after/{menu,combat,stages,intro,settings,pause}.png` screenshots; and the before menu, combat, intro, and settings screenshots. The runtime screenshots are 1280 × 720.
- Used the installed Godot code-review guidance and the bounded render/review part of Dream-loop Pro. The generated target is an art-direction reference, not evidence of executable UI or a requirement to reproduce its pixels. Actual Thai readability, input access, and unobstructed combat take precedence.
- No code edited, no test run, no GPU/browser session, and no public repository code executed by this reviewer. Test results reported by the implementers are separate evidence; they do not establish rendered smoothness, Web FPS, or human playability here.

## Code finding

**P2 — A teacher can damage a target behind its visible punch.** At the reviewed `Scripts/teacher_ally.gd:147`, attack initiation checks distance, cooldown, and line of sight, but not facing. Contact at lines 197–201 similarly checks distance, height, and line of sight only. `_face()` at line 241 turns at 8 radians/second, whereas contact occurs after 0.20 seconds. For an enemy acquired directly behind the teacher at close range, the teacher can turn only approximately 99° including the initiating physics tick before damage is applied, leaving the enemy roughly 80° away from the punch direction. This is a code-derived reproduction, not an observed runtime capture. Require sufficient facing before starting a jab and/or validate an impact arc; add a fixture with an enemy initially behind the teacher. The existing target fixture places the enemy to the side and does not cover the 180° case. Sent to root and the gameplay owner before this report.

No additional concrete regression was found in the reviewed player/enemy phase preservation and attack sequencing, separate ally damage entry point, teacher target eligibility, pause/clear/restart/menu cleanup, or stage wiring. This is bounded source review, not a claim that all possible gameplay states have been proven correct. The teacher's separate damage API correctly prevents the player's optional one-hit God Mode from being inherited by autonomous attacks. The companion uses world collision while its layer zero prevents it from blocking actors; damage targets remain members of the active enemy list.

**Subsequent source recheck:** the gameplay owner added facing-dot thresholds of 0.65 at attack initiation and 0.4 at contact, with three rear-target/cross-behind assertions. The inspected `evidence/2026-10-12-polish/teacher_companion_checks.json` records 50 checks and zero failures. This resolves the code finding on source and fixture evidence; this reviewer did not independently execute that test. The owner also reduced the world caption pixel size to 0.0022, lowered it to y=2.2, and kept only the name after rescue. That is a suitable implementation response to visual finding 4, but the first-pass images below predate it and need a new capture before its visual result is accepted.

## Visual verdict: first pass 7.6 / 10

Scores are an editorial review of these screenshots, not an automated accessibility or performance measurement. Each category has a maximum of 2 points.

| Category | Score | Assessment |
| --- | ---: | --- |
| Composition | 1.3 | The title/menu occupies a controlled left column and leaves the cover figures visible. The oversized ally card and near-camera world caption consume unnecessary combat space. |
| Hierarchy | 1.6 | One blood-red primary action, restrained brass dividers, and distinct stage cards improve scanning. The cropped settings action and absent initial intro action weaken the path forward. |
| Palette | 1.8 | Ink, bone, blood red, and brass stay consistent across menus and modal panels. Mint remains a useful ally cue instead of making every element compete for attention. |
| Typography | 1.6 | Thai body copy is legible, title edges are cleaner than the previous offset-shadow treatment, and dialogue remains readable. The teacher's world label is much too prominent at follow distance; small footer/control text remains secondary. |
| Clarity | 1.3 | Stage descriptions and pause actions are clear. Menu/footer overflow, partial settings action, and the ally panel footprint need correction before calling this pass finished. |

### Actionable findings

1. **P2, already identified by root: combat ally card reserves about 322 px of height for about 80 px of content.** In `after/combat.png`, the card extends from approximately y=179 to y=501, covering the left view into the room. Fit the panel to its actual content. Recheck with all three teachers and the longest cooldown/status text, not just the idle label.
2. **P2, already identified by root: the menu unnecessarily scrolls at 720p and loses its footer.** `after/menu.png` shows a vertical scroll bar beside the six actions, while the course/group/control footer present in `before/menu.png` is outside the visible region. Reduce vertical spacing or title margins so six actions plus the footer fit at the supported desktop size. Preserve scrolling at genuinely smaller sizes.
3. **P2, already identified by root: settings clips the bottom of its primary action.** In `after/settings.png`, the button begins near y=599 but its lower edge is cut by the scroll viewport near y=648. The old settings screenshot fits the entire button. Reduce avoidable stack height and verify both the complete rectangle and keyboard focus visibility at 720p.
4. **P2, additional finding: the newly mobile teacher's world caption obstructs the room.** In `after/combat.png`, the two-line name/status is approximately 240 × 90 px near x=350–590, y=180–270 and overlaps the CAPTCHA signage. The same information already appears in the ally HUD. At `Scripts/teacher_ally.gd:65–69,86–90`, retain a prominent rescue label while waiting, then reduce its size and/or use a compact single-line name after rescue. A proximity fade is another possible implementation, but a small static label is simpler. Do not make the rescue objective harder to find. Root and gameplay owner informed.
5. **P3, existing usability limitation rather than a new release blocker: the initial intro view has no visible forward action.** Both before and after intro screenshots put the action below the fold; the after version displays fewer story lines at once. The code intentionally opens long pages at the heading and lets Tab reach the action, so this screenshot does not prove the action is inaccessible. Prefer an explicit scroll cue or a fixed footer action if this screen is revised later. Preserve the story's line spacing rather than shrinking Thai text to force everything into one panel.

### What should remain

- Keep the simpler title without the former heavy offset shadow. It reads clearly at the actual runtime resolution.
- Keep the stage selection's three concise two-line cards. Titles and descriptions fit cleanly in the captured view, with the brass, mint, and red accents helping separate them.
- Keep the pause screen's single primary “เล่นต่อ” action and subdued background. Its four actions fit and the new teacher-support sentence accurately distinguishes automatic help from the T skill.
- Keep native Thai text and actual control labels. The generated image's typography, arrows, and decorative ledger are suggestions; it is not a reason to replace the font, introduce new external assets, or compromise focus/scroll behavior.
- The target depicts the menu cover only. It is not an appropriate graphical benchmark for the in-engine combat room, and these still images cannot demonstrate locomotion smoothness or frame rate.

## Follow-up acceptance for the next capture

Reinspect menu, settings, and combat at 1280 × 720 after the targeted fixes; verify the footer and complete save button are visible, the ally card fits its content, and the following teacher no longer obscures central signage. Use the existing responsive/focus tests for other resolutions and input access. Recheck the rear-target melee case through the gameplay owner's targeted fixture. Do not infer that the first-pass score or these screenshots certify publication readiness.

## Snapshot identity

If the implementer replaces the images at the same paths, these hashes identify exactly the first pass scored above. SHA-256:

| File | SHA-256 |
| --- | --- |
| `.dream-loop/target.png` | `64D0982F71B6E3F59120E46C11975C33E5D67FB86CFC7CC06B23DD78CCE6771E` |
| `after/menu.png` | `1D82BC3CFEC789EBBF2CFAEF1A97954CC4DC49400520836FD73B13F85FD64341` |
| `after/combat.png` | `38470C2E90B91AB4A4B97354274813E01667E992C33C5BB55401DF2A46574B98` |
| `after/stages.png` | `FA59DC35C31D0BEEA65530428E9292066E724442D02BAFC34195C1A332795492` |
| `after/intro.png` | `2BD24AFAEC998160ACB2A54575E11065A7B3719ADEF6DFC9B2D4561808372F84` |
| `after/settings.png` | `36025165128E793FCBE3EFFD426ED3462608809F979B11E9F287F470A93116F2` |
| `after/pause.png` | `F69C9A0E530311B097855E0AD766A4205062578C79F4E2644355937B7257CDE5` |

## Final visual review — accepted within the inspected scope

Reviewed the final matching screenshots in `evidence/2026-10-12-polish/final/{menu,combat,settings,stages,intro,pause}.png`, the six requested 1280 × 720 responsive screenshots, their intro-bottom state, and eight useful 960 × 540 screenshots including scrolled settings, stage selection, and intro states. In total, 21 final images were inspected. The first-pass findings and score above remain historical evidence; this section gives their final disposition.

**Final score: 8.7 / 10. No remaining P1/P2 visual blocker was found in the inspected screens.** This accepts the bounded UI polish visually; it does not certify Web performance, animation smoothness, every gameplay view, or publication readiness.

| Category | Final score / 2 | Reason |
| --- | ---: | --- |
| Composition | 1.8 | The six-action desktop menu and footer fit without unnecessary scrolling. The compact ally card restores the left combat view. |
| Hierarchy | 1.8 | The primary menu/settings/pause actions are complete and easy to identify. Stage titles and descriptions remain distinct. |
| Palette | 1.8 | The consistent dark, brass, bone, and red treatment supports the cover art; ally mint remains a functional cue. |
| Typography | 1.7 | Thai text is readable in the inspected desktop and compact layouts. The nearby teacher's single-line caption is subordinate to the scene instead of covering it. |
| Clarity | 1.6 | HUD regions do not overlap in the inspected 720p/540p boss views. Scrolled compact modals show complete actions; the initial long intro still requires scrolling before its start action appears. |

### Final disposition of the first-pass findings

| Finding | Disposition | Inspected evidence |
| --- | --- | --- |
| Oversized ally card | **Resolved visually.** Its height is now approximately 108 px instead of 322 px, fitting the name, status, cooldown text, and bar. | `final/combat.png`; both responsive `game_hud.png` images |
| Desktop menu scroll/footer loss | **Resolved visually at 1280 × 720.** All six actions and the course/group/control footer are visible, with no unnecessary scroll bar. At 960 × 540 the menu intentionally scrolls while preserving readable text; this is not the former 720p overflow defect. | `final/menu.png`; `final/ui/1280x720/menu.png`; `final/ui/960x540/menu.png` |
| Settings save-button clipping | **Resolved visually at 1280 × 720.** The entire action rectangle is visible. At 960 × 540, the bottom capture shows the full action after scrolling rather than a permanently clipped control. | `final/settings.png`; `final/ui/1280x720/settings.png`; `final/ui/960x540/settings_bottom.png` |
| Near-camera teacher caption | **Resolved in the captured nearby-following view.** The matching CAPTCHA room capture now shows a compact single-line name roughly 95 × 23 px instead of the previous large two-line block. The teacher is visibly nearby beside the student, so this is direct visual evidence rather than inference from a distant model. The caption no longer obscures the CAPTCHA sign; the existing ally HUD still explains readiness. | `final/combat.png`, compared with first-pass `after/combat.png`; responsive boss-room HUD views support the same result |
| Long intro's initially invisible action | **Accepted P3 limitation, not a new regression.** The initial page still needs scrolling. The 720p and 540p bottom captures show a complete, legible “ถึงเวลาเข้าเรียน...ภาคสนาม” button. A future explicit scroll cue could improve discoverability, but no scope expansion or story rewrite is required for this polish task. | `final/intro.png`; both inspected `intro_bottom.png` images |
| Teacher rear-facing melee | **Closed on the source/fixture evidence recorded above.** Still images add no evidence about contact timing, so the final visual review does not restate this as a rendered timing test. | Facing guards and the previously inspected 50-check companion receipt |

The 960 × 540 stage-selection bottom capture shows all three stage cards and the complete Back action without horizontal text overflow. The compact pause screen fits all four actions, and the boss bar remains between the player and objective panels in the compact HUD. These are observations of captured states, not independent input execution.

No additional capture is required to judge the reported teacher-label obstruction: the matching final combat screenshot includes the close teacher in the same room as the first pass. No production files, browser state, or GPU workload were changed during this final review.

### Final image identity

SHA-256. Paths below are relative to `evidence/2026-10-12-polish/final/`.

| Inspected file | SHA-256 |
| --- | --- |
| `menu.png` | `8BAF1E240E95E20267E9F8AAC756E642258A89DD5B9871D8DCEA1EFDB4A7E204` |
| `combat.png` | `975D035BC1C34211D8AFFDB714B8E6CEB8145AE5FC13D84CE117019055D08475` |
| `settings.png` | `D64F96AA33E1F06021BBA30F64B9CFE2376151A7C65FB398B42B2C1A1E334A73` |
| `stages.png` | `6EE01696974AE0B56F6F4EFCABC994D737FE9A99633EFACE9A28194BC0342586` |
| `intro.png` | `2BD24AFAEC998160ACB2A54575E11065A7B3719ADEF6DFC9B2D4561808372F84` |
| `pause.png` | `B243089E490695B04427279D6D4DD45624DE82E61D8392FF60D3291B9F6BA5BA` |
| `ui/1280x720/menu.png` | `8BAF1E240E95E20267E9F8AAC756E642258A89DD5B9871D8DCEA1EFDB4A7E204` |
| `ui/1280x720/settings.png` | `FBE01E7582B1F7E5E5651C1764F2BCCC3CC2594EDA639743D77B5E5F849E5818` |
| `ui/1280x720/game_hud.png` | `7A23758FCF0DEE0A7FA690BC5DEFC287D8871311A35608B0166845871052DA08` |
| `ui/1280x720/stage_select.png` | `0926C9D927E7B69CCC3D614964E24A44EA7F72B44707B212A81F316292B7E024` |
| `ui/1280x720/pause.png` | `C8BA7E2132E200147F512EA5B4ED05FB3688322CB1ABDCF24A7D199881F7933F` |
| `ui/1280x720/intro.png` | `2BD24AFAEC998160ACB2A54575E11065A7B3719ADEF6DFC9B2D4561808372F84` |
| `ui/1280x720/intro_bottom.png` | `70D11B4270E1750E58249CD43DB95C018D97CB4AADC585F0221A1EB7D2D13649` |
| `ui/960x540/menu.png` | `C79A92B5ABDFAEB43B03409B64EB4280F19F23E61E768363C990A0925B02C5F0` |
| `ui/960x540/settings.png` | `05A0412E4B45A4497256747A11D1928DA8AF53B4AD8BCA2F8DBF053787C59E9A` |
| `ui/960x540/game_hud.png` | `FC2ABA3409FE16415427558AE4F50AA7471958E15EDB10742E63FA2BAEA41C61` |
| `ui/960x540/settings_bottom.png` | `A783F5CED29717AC3EB31CBC4EC8D3564C9310AE27FA8E55E4B0BFC2C805BA4C` |
| `ui/960x540/stage_select.png` | `717D817EA88AC12B7945BE8D17BE983D784CDB2F1D0F72DED39B6B1C9F30436B` |
| `ui/960x540/stage_select_bottom.png` | `E8550EDB7017F3EDD5B7BC0D7200ED90E706DF43484D81C5B4299AA2C5C09B21` |
| `ui/960x540/pause.png` | `BE2075097C68F30BA957FF2D61D8F72A7B18386CC240E51B5C87B61FA9F28FCC` |
| `ui/960x540/intro_bottom.png` | `364970978C0D2DBEC813130DAADF48D014BBCC632E94DC6E864C85102C9DC0DE` |

## Web glyph correction — final proof addendum

After the review above, the owner corrected characters that relied on an unavailable Web font fallback and re-exported `0.6-ally-polish2`: the menu's box-drawing separator became ASCII `/`; the ending's arrow was replaced by the Thai phrase `F เป็น D`; resume uses `›`; and the electrical sign uses `ไฟฟ้า` instead of the lightning glyph.

Independently inspected `evidence/2026-10-12-polish/edge_final_menu.jpg`, the supplied actual Edge capture at 1912 × 914. All six menu rows visibly render their `/` separators, the start action's chevron is present, and the Thai title, copy, enabled continue row, and footer are legible without missing-character boxes or clipping. **The menu glyph correction is visually accepted; the overall bounded visual score remains 8.7 / 10.** This single menu image does not independently prove the ending, pause/resume, or electrical-sign states; those replacements are recorded as the owner's reported fix, not as scenes inspected in this addendum.

The six native matching screenshots were overwritten after the font correction. Their earlier six hashes inside the 21-image table above are retained as historical snapshot identities, not descriptions of the files currently at those paths. The new hashes below identify the replacement files; this addendum rehashed them without claiming another full visual review of all six. The separately stored responsive screenshot hashes above continue to identify the responsive capture snapshot reviewed at that time.

Paths are relative to `evidence/2026-10-12-polish/`; SHA-256:

| Current file | SHA-256 |
| --- | --- |
| `edge_final_menu.jpg` | `2D0F3466553506E57F63C617EA9E8E8D0A4F7CA2182729AE611E18E61057811A` |
| `final/menu.png` | `7DB8B080F816883B46B25BAA1B8F281FB852C3476AA6F0A20E668E9B42FF136C` |
| `final/combat.png` | `471DDDC6A48953F3507A017F47D6367CF50FCDFC84FCD2128153B762C700C4F4` |
| `final/settings.png` | `4F070F99A80000185A349986193A819569A047966C9D81DE934897182074BC2A` |
| `final/stages.png` | `147259CD85DEB629BEC183BD7241C7534F6477F0371CBE1D34463C903527F36E` |
| `final/intro.png` | `2BD24AFAEC998160ACB2A54575E11065A7B3719ADEF6DFC9B2D4561808372F84` |
| `final/pause.png` | `E81732101B1560EA6856C0253BD019B6A3CEE40B804231E48CBC557C3D968345` |

Only this review document was appended. No production files, research report, browser state, GPU workload, or historical hashes were changed by this reviewer.
