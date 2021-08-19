import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';

import '../AlbumImage.dart';
import '../../services/processArtist.dart';
import '../../services/mediaStateStream.dart';

class _QueueListStreamState {
  _QueueListStreamState(
    this.queue,
    this.mediaState,
    this.shuffleIndicies,
  );

  final List<MediaItem>? queue;
  final MediaState mediaState;
  final dynamic shuffleIndicies;
}

class QueueList extends StatefulWidget {
  const QueueList({Key? key, required this.scrollController}) : super(key: key);

  final ScrollController scrollController;

  @override
  _QueueListState createState() => _QueueListState();
}

class _QueueListState extends State<QueueList> {
  final _audioHandler = GetIt.instance<AudioHandler>();
  List<MediaItem>? _queue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_QueueListStreamState>(
      // stream: AudioService.queueStream,
      stream: Rx.combineLatest3<List<MediaItem>?, MediaState, dynamic,
              _QueueListStreamState>(
          _audioHandler.queue,
          mediaStateStream,
          // We turn this future into a stream because using rxdart is
          // easier than having nested StreamBuilders/FutureBuilders
          _audioHandler.customAction("getShuffleIndices").asStream(),
          (a, b, c) => _QueueListStreamState(a, b, c)),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if (_queue == null) {
            _queue = snapshot.data!.queue;
          }
          return PrimaryScrollController(
            controller: widget.scrollController,
            child: ReorderableListView.builder(
              itemCount: snapshot.data!.queue?.length ?? 0,
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  // _queue?.insert(newIndex, _queue![oldIndex]);
                  // _queue?.removeAt(oldIndex);
                  int? smallerThanNewIndex;
                  if (oldIndex < newIndex) {
                    // When we're moving an item backwards, we need to reduce
                    // newIndex by 1 to account for there being a new item added
                    // before newIndex.
                    smallerThanNewIndex = newIndex - 1;
                  }
                  final item = _queue?.removeAt(oldIndex);
                  _queue?.insert(smallerThanNewIndex ?? newIndex, item!);
                });
                await _audioHandler.customAction("reorderQueue", {
                  "oldIndex": oldIndex,
                  "newIndex": newIndex,
                });
              },
              itemBuilder: (context, index) {
                final actualIndex =
                    _audioHandler.playbackState == AudioServiceShuffleMode.all
                        ? snapshot.data!.shuffleIndicies![index]
                        : index;
                return Dismissible(
                  key: ValueKey(snapshot.data!.queue![actualIndex].id),
                  onDismissed: (direction) async {
                    setState(() {
                      _queue?.removeAt(actualIndex);
                    });
                    await _audioHandler.removeQueueItemAt(actualIndex);
                  },
                  child: ListTile(
                    leading: AlbumImage(
                      itemId: _queue?[actualIndex].extras?["parentId"],
                    ),
                    title: Text(
                        snapshot.data!.queue?[actualIndex].title ??
                            "Unknown Name",
                        style: snapshot.data!.mediaState.mediaItem ==
                                snapshot.data!.queue?[actualIndex]
                            ? TextStyle(color: Theme.of(context).accentColor)
                            : null),
                    subtitle: Text(processArtist(
                        snapshot.data!.queue?[actualIndex].artist)),
                  ),
                );
              },
            ),
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}
