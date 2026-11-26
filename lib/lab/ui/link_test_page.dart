import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zt_assist/zt_assist.dart';

import '../prompts.dart';

/// One request the link test can send.
class LinkSample {
  const LinkSample(this.label, this.request);

  final String label;
  final ZtAssistRequest request;
}

/// The requests of the link test: the jobs the first features in the other
/// apps will ask for, on texts the phone test already uses.
final List<LinkSample> linkSamples = [
  LinkSample(
    'Summarize, English',
    ZtAssistRequest(task: ZtAssistTask.summarize, text: labEnglishNote),
  ),
  LinkSample(
    'Summarize, Hebrew',
    ZtAssistRequest(task: ZtAssistTask.summarize, text: labHebrewNote),
  ),
  const LinkSample(
    'Proofread, Hebrew',
    ZtAssistRequest(
      task: ZtAssistTask.proofread,
      text:
          'שלום רב, רצתי לברר האם אפשר לדחות את הפגישה שנקבה ליום רבעי בשעה '
          'עשר. יש לי התנגשות עם תור לרופה ואשמח לקבוע מועד חלופי בהקדם '
          'האפשרי.',
    ),
  ),
  // The longest answer of the four: the one to read the writing speed from.
  LinkSample(
    'Rewrite, Hebrew (long answer)',
    ZtAssistRequest(task: ZtAssistTask.rewrite, text: labHebrewNote),
  ),
];

/// Asks ZT Assist the way another Zero-Trust app will: through the
/// `zt_assist` package and the answering service, not through the chat's own
/// model. Shows the answer and how fast it was written, so the link can be
/// checked on a phone before another app uses it.
class LinkTestPage extends StatefulWidget {
  const LinkTestPage({super.key, this.assist, this.onActivity});

  /// [ZtAssist.instance] when left out; a fake in tests.
  final ZtAssist? assist;

  /// Called while an answer is being written, so the app does not lock
  /// itself in the middle.
  final VoidCallback? onActivity;

  @override
  State<LinkTestPage> createState() => _LinkTestPageState();
}

class _LinkTestPageState extends State<LinkTestPage> {
  late final ZtAssist _assist = widget.assist ?? ZtAssist.instance;

  ZtAssistAvailability? _availability;
  int _sample = 0;
  StreamSubscription<ZtAssistEvent>? _answering;
  final Stopwatch _watch = Stopwatch();
  String _answer = '';
  ZtAssistDone? _done;
  String? _problem;
  bool _stoppedHere = false;

  bool get _running => _answering != null;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    unawaited(_answering?.cancel());
    // The model this page loaded is not kept for a test nobody is looking
    // at any more.
    unawaited(_assist.release());
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _availability = null);
    final availability = await _assist.availability();
    if (!mounted) return;
    setState(() => _availability = availability);
  }

  void _ask() {
    setState(() {
      _answer = '';
      _done = null;
      _problem = null;
      _stoppedHere = false;
    });
    _watch
      ..reset()
      ..start();
    _answering = _assist
        .ask(linkSamples[_sample].request)
        .listen(
          (event) {
            if (!mounted) return;
            widget.onActivity?.call();
            setState(() {
              switch (event) {
                case ZtAssistChunk(:final text):
                  _answer += text;
                case ZtAssistDone():
                  _done = event;
              }
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _problem = error is ZtAssistException
                  ? _problemText(error)
                  : 'It failed: $error';
            });
          },
          onDone: () {
            _watch.stop();
            if (!mounted) return;
            setState(() => _answering = null);
            // A first answer can change the state: a model that was missing
            // is still missing, one that failed to load says so above.
            unawaited(_check());
          },
        );
    setState(() {});
  }

  Future<void> _stop() async {
    final answering = _answering;
    if (answering == null) return;
    _watch.stop();
    setState(() {
      _answering = null;
      _stoppedHere = true;
    });
    await answering.cancel();
  }

  static String _problemText(ZtAssistException problem) {
    final why = switch (problem.error) {
      ZtAssistError.notInstalled => 'ZT Assist was not found on this phone.',
      ZtAssistError.noModel => 'No model is on this phone. Download one first.',
      ZtAssistError.loadFailed =>
        'The model did not load. Most often the phone is short of free '
            'memory: close other apps and try again.',
      ZtAssistError.needsUpdate =>
        'The answering part is older than the asking part.',
      ZtAssistError.stopped =>
        'The answering part was stopped in the middle, most often because '
            'the phone took its memory back.',
      ZtAssistError.failed => 'It failed.',
    };
    final detail = problem.detail;
    return detail == null || detail.isEmpty ? why : '$why\n$detail';
  }

  static String _seconds(Duration time) =>
      '${(time.inMilliseconds / 1000).toStringAsFixed(1)} s';

  /// What the numbers of a finished answer say, in words.
  String _report(ZtAssistDone done) {
    final speed = done.tokensPerSecond;
    final lines = [
      '${done.tokens} tokens. The model read for '
          '${_seconds(done.timeToFirstPiece)} and wrote for '
          '${_seconds(done.duration - done.timeToFirstPiece)}'
          '${speed == null ? '' : ', ${speed.toStringAsFixed(1)} tokens a second'}.',
      'From the tap to the end: ${_seconds(_watch.elapsed)}. The first '
          'answer after a while includes loading the model.',
      if (done.stopped) 'It was stopped before its end.',
      if (done.truncated)
        'The text was longer than the model takes; only its beginning was '
            'read.',
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availability = _availability;
    final done = _done;
    final problem = _problem;
    return Scaffold(
      appBar: AppBar(title: const Text('Link for other apps')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Other Zero-Trust apps will ask ZT Assist for summaries, '
            'corrections and the like. This page asks the same way they '
            'will: through the part of ZT Assist that answers other apps, '
            'which runs apart from the chat with a model of its own in '
            'memory. Nothing leaves the phone.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              key: const Key('link-state'),
              leading: availability == null
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      availability == ZtAssistAvailability.ready
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                    ),
              title: Text(switch (availability) {
                null => 'Asking whether it is ready...',
                ZtAssistAvailability.ready => 'Ready to answer other apps',
                ZtAssistAvailability.needsModel => 'No model on this phone',
                ZtAssistAvailability.needsUpdate =>
                  'The answering part is too old',
                ZtAssistAvailability.notInstalled => 'ZT Assist was not found',
                ZtAssistAvailability.unavailable => 'It did not answer',
              }),
              subtitle: switch (availability) {
                ZtAssistAvailability.needsModel => const Text(
                  'Download a model on the previous page or in the chat.',
                ),
                ZtAssistAvailability.unavailable => const Text(
                  'The answering part did not start. Tap to ask again.',
                ),
                _ => null,
              },
              onTap: _running ? null : _check,
            ),
          ),
          const SizedBox(height: 16),
          Text('Request', style: theme.textTheme.titleMedium),
          RadioGroup<int>(
            groupValue: _sample,
            onChanged: (value) {
              if (_running || value == null) return;
              setState(() => _sample = value);
            },
            child: Column(
              children: [
                for (var i = 0; i < linkSamples.length; i++)
                  RadioListTile<int>(
                    value: i,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(linkSamples[i].label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // The suite's buttons are as wide as they are allowed to be, so
          // each gets its own row.
          if (_running)
            OutlinedButton.icon(
              key: const Key('link-stop'),
              onPressed: _stop,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            )
          else
            FilledButton.icon(
              key: const Key('link-ask'),
              onPressed: _ask,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Ask'),
            ),
          const SizedBox(height: 16),
          if (_running && _answer.isEmpty)
            const Text('Loading the model and reading the text...'),
          if (_answer.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _answer.trim(),
                  key: const Key('link-answer'),
                ),
              ),
            ),
          if (problem != null) ...[
            const SizedBox(height: 8),
            Text(
              problem,
              key: const Key('link-problem'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_stoppedHere) ...[
            const SizedBox(height: 8),
            const Text('Stopped.'),
          ],
          if (done != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              _report(done),
              key: const Key('link-report'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'For a fair speed reading, ask twice and read the second answer: '
            'the first one loads the model. The model stays in memory for two '
            'minutes after the last answer and is freed when you leave this '
            'page.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
