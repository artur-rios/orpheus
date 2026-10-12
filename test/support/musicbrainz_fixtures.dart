/// MusicBrainz answers, as the service shapes them, trimmed to the fields
/// this application reads. Invented ids; real field names.
library;

/// `GET release?query=…`
const Map<String, Object?> releaseSearch = {
  'count': 2,
  'releases': [
    {
      'id': 'rel-1',
      'score': 100,
      'title': 'OK Computer',
      'status': 'Official',
      'date': '1997-05-21',
      'country': 'GB',
      'disambiguation': '',
      'track-count': 12,
      'artist-credit': [
        {
          'name': 'Radiohead',
          'joinphrase': '',
          'artist': {'id': 'a1', 'name': 'Radiohead'},
        },
      ],
      'release-group': {
        'id': 'rg-1',
        'primary-type': 'Album',
        'secondary-types': <String>[],
      },
      'media': [
        {'format': 'CD', 'track-count': 12},
      ],
    },
    {
      'id': 'rel-2',
      'score': 92,
      'title': 'OK Computer OKNOTOK 1997 2017',
      'status': 'Official',
      'date': '2017-06-23',
      'country': 'XW',
      'disambiguation': 'remaster',
      'track-count': 23,
      'artist-credit': [
        {'name': 'Radiohead', 'joinphrase': ''},
      ],
      'release-group': {'id': 'rg-2', 'primary-type': 'Album'},
      'media': [
        {'format': 'Digital Media', 'track-count': 23},
      ],
    },
  ],
};

/// `GET release/rel-1?inc=recordings+artist-credits+genres+release-groups+media`
const Map<String, Object?> releaseLookup = {
  'id': 'rel-1',
  'title': 'OK Computer',
  'status': 'Official',
  'date': '1997-05-21',
  'country': 'GB',
  'artist-credit': [
    {'name': 'Radiohead', 'joinphrase': ''},
  ],
  'release-group': {
    'id': 'rg-1',
    'primary-type': 'Album',
    'secondary-types': <String>[],
  },
  'genres': [
    {'name': 'art rock', 'count': 4},
    {'name': 'alternative rock', 'count': 9},
  ],
  'media': [
    {
      'position': 1,
      'format': 'CD',
      'track-count': 2,
      'tracks': [
        {
          'position': 1,
          'number': '1',
          'title': 'Airbag',
          'length': 284000,
          'artist-credit': [
            {'name': 'Radiohead', 'joinphrase': ''},
          ],
          'recording': {'id': 'rec-1'},
        },
        {
          'position': 2,
          'number': '2',
          'title': 'Paranoid Android',
          'length': null,
          'recording': {
            'id': 'rec-2',
            'artist-credit': [
              {'name': 'Radiohead', 'joinphrase': ''},
            ],
          },
        },
      ],
    },
  ],
};

/// `GET release-group/rg-1?inc=genres`
const Map<String, Object?> releaseGroupLookup = {
  'id': 'rg-1',
  'genres': [
    {'name': 'rock', 'count': 3},
  ],
};

/// `GET recording?query=…`
const Map<String, Object?> recordingSearch = {
  'recordings': [
    {
      'id': 'rec-3',
      'score': 98,
      'title': 'Lucky',
      'length': 259000,
      'artist-credit': [
        {'name': 'Radiohead', 'joinphrase': ''},
      ],
      'releases': [
        {
          'id': 'rel-1',
          'title': 'OK Computer',
          'status': 'Official',
          'date': '1997-05-21',
          'track-count': 12,
          'release-group': {
            'id': 'rg-1',
            'primary-type': 'Album',
            'secondary-types': <String>[],
          },
          'media': [
            {
              'position': 1,
              'format': 'CD',
              'track-count': 12,
              'track-offset': 10,
              'track': [
                {'id': 't', 'number': '11', 'title': 'Lucky', 'length': 259000},
              ],
            },
          ],
        },
      ],
    },
  ],
};
