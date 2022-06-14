import 'package:finamp/components/MusicScreen/AlbumItemListTile.dart';
import 'package:finamp/services/FinampSettingsHelper.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../models/JellyfinModels.dart';
import '../../services/JellyfinApiData.dart';
import '../../screens/ArtistScreen.dart';
import '../../screens/AlbumScreen.dart';
import '../errorSnackbar.dart';
import 'AlbumItemCard.dart';

enum _AlbumListTileMenuItems {
  AddFavourite,
  RemoveFavourite,
  AddToMixList,
  RemoveFromMixList,
}

/// This widget is kind of a shell around AlbumItemCard and AlbumItemListTile.
/// Depending on the values given, a list tile or a card will be returned. This
/// widget exists to handle the dropdown stuff and other stuff shared between
/// the two widgets.
class AlbumItem extends StatefulWidget {
  const AlbumItem({
    Key? key,
    required this.album,
    this.parentType,
    this.onTap,
    this.isGrid = false,
    this.gridAddSettingsListener = false,
  }) : super(key: key);

  /// The album (or item, I just used to call items albums before Finamp
  /// supported other types) to show in the widget.
  final BaseItemDto album;

  /// The parent type of the item. Used to change onTap functionality for stuff
  /// like artists.
  final String? parentType;

  /// A custom onTap can be provided to override the default value, which is to
  /// open the item's album/artist screen.
  final void Function()? onTap;

  /// If specified, use cards instead of list tiles. Use this if you want to use
  /// this widget in a grid view.
  final bool isGrid;

  /// If true, the grid item will use a ValueListenableBuilder to check whether
  /// or not to show the text. You'll want to set this to false if the
  /// [AlbumItem] would be rebuilt by FinampSettings anyway.
  final bool gridAddSettingsListener;

  @override
  _AlbumItemState createState() => _AlbumItemState();
}

class _AlbumItemState extends State<AlbumItem> {
  late BaseItemDto mutableAlbum;

  late Function() onTap;

  @override
  void initState() {
    super.initState();
    mutableAlbum = widget.album;

    // this is jank lol
    onTap = widget.onTap ??
        () {
          if (mutableAlbum.type == "MusicArtist" ||
              mutableAlbum.type == "MusicGenre") {
            Navigator.of(context)
                .pushNamed(ArtistScreen.routeName, arguments: mutableAlbum);
          } else {
            Navigator.of(context)
                .pushNamed(AlbumScreen.routeName, arguments: mutableAlbum);
          }
        };
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Padding(
      padding: widget.isGrid
          ? Theme.of(context).cardTheme.margin ?? const EdgeInsets.all(4.0)
          : EdgeInsets.zero,
      child: GestureDetector(
        onLongPressStart: (details) async {
          Feedback.forLongPress(context);

          if (FinampSettingsHelper.finampSettings.isOffline) {
            // If offline, don't show the context menu since the only options here
            // are for online.
            return;
          }

          final jellyfinApiData = GetIt.instance<JellyfinApiData>();

          final selection = await showMenu<_AlbumListTileMenuItems>(
            context: context,
            position: RelativeRect.fromLTRB(
              details.globalPosition.dx,
              details.globalPosition.dy,
              screenSize.width - details.globalPosition.dx,
              screenSize.height - details.globalPosition.dy,
            ),
            items: [
              mutableAlbum.userData!.isFavorite
                  ? const PopupMenuItem<_AlbumListTileMenuItems>(
                      value: _AlbumListTileMenuItems.RemoveFavourite,
                      child: ListTile(
                        leading: Icon(Icons.star_border),
                        title: Text("Remove Favourite"),
                      ),
                    )
                  : const PopupMenuItem<_AlbumListTileMenuItems>(
                      value: _AlbumListTileMenuItems.AddFavourite,
                      child: ListTile(
                        leading: Icon(Icons.star),
                        title: Text("Add Favourite"),
                      ),
                    ),
              jellyfinApiData.selectedMixAlbumIds.contains(mutableAlbum.id) ?
              const PopupMenuItem<_AlbumListTileMenuItems>(
                value: _AlbumListTileMenuItems.RemoveFromMixList,
                child: ListTile(
                  leading: Icon(Icons.explore_off),
                  title: Text("Remove From Mix"),
                ),
              ) : const PopupMenuItem<_AlbumListTileMenuItems>(
                value: _AlbumListTileMenuItems.AddToMixList,
                child: ListTile(
                  leading: Icon(Icons.explore),
                  title: Text("Add To Mix"),
                ),
              ),
            ],
          );

          switch (selection) {
            case _AlbumListTileMenuItems.AddFavourite:
              try {
                final newUserData =
                    await jellyfinApiData.addFavourite(mutableAlbum.id);
                setState(() {
                  mutableAlbum.userData = newUserData;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Favourite added.")));
              } catch (e) {
                errorSnackbar(e, context);
              }
              break;
            case _AlbumListTileMenuItems.RemoveFavourite:
              try {
                final newUserData =
                    await jellyfinApiData.removeFavourite(mutableAlbum.id);
                setState(() {
                  mutableAlbum.userData = newUserData;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Favourite removed.")));
              } catch (e) {
                errorSnackbar(e, context);
              }
              break;
            case _AlbumListTileMenuItems.AddToMixList:
              try {
                jellyfinApiData.addAlbumToMixBuilderList(mutableAlbum);
                setState(() {});
              } catch (e){
                errorSnackbar(e, context);
              }
              break;
            case _AlbumListTileMenuItems.RemoveFromMixList:
              try {
                jellyfinApiData.removeAlbumFromBuilderList(mutableAlbum);
                setState(() {});
              } catch (e){
                errorSnackbar(e, context);
              }
              break;
            case null:
              break;
          }
        },
        child: widget.isGrid
            ? AlbumItemCard(
                item: mutableAlbum,
                onTap: onTap,
                parentType: widget.parentType,
                addSettingsListener: widget.gridAddSettingsListener,
              )
            : AlbumItemListTile(
                item: mutableAlbum,
                onTap: onTap,
                parentType: widget.parentType,
              ),
      ),
    );
  }
}
