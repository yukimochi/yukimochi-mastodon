# frozen_string_literal: true

class PublicStatusesIndex < Chewy::Index
  include DatetimeClampingConcern

  settings index: index_preset(refresh_interval: '30s', number_of_shards: 5), analysis: {
    filter: {
      english_stop: {
        type: 'stop',
        stopwords: '_english_',
      },

      english_stemmer: {
        type: 'stemmer',
        language: 'english',
      },

      english_possessive_stemmer: {
        type: 'stemmer',
        language: 'possessive_english',
      },

      kuromoji_pos_filter: {
        type: 'kuromoji_part_of_speech',
        stoptags: %w(助詞 助動詞 接続詞 感動詞),
      },

      kuromoji_stemmer_filter: {
        type: 'kuromoji_stemmer',
      },

      ja_stop_filter: {
        type: 'stop',
        stopwords: '_japanese_',
      },
    },

    analyzer: {
      verbatim: {
        tokenizer: 'uax_url_email',
        filter: %w(lowercase),
      },

      content: {
        tokenizer: 'standard',
        filter: %w(
          lowercase
          asciifolding
          cjk_width
          elision
          english_possessive_stemmer
          english_stop
          english_stemmer
        ),
      },

      hashtag: {
        tokenizer: 'keyword',
        filter: %w(
          word_delimiter_graph
          lowercase
          asciifolding
          cjk_width
        ),
      },

      japanese_content: {
        tokenizer: 'kuromoji_tokenizer',
        filter: %w(
          kuromoji_baseform
          kuromoji_pos_filter
          kuromoji_stemmer_filter
          ja_stop_filter
          lowercase
          cjk_width
        ),
      },
    },
  }

  index_scope ::Status.unscoped
    .kept
    .indexable
    .includes(:media_attachments, :preloadable_poll, :tags, preview_cards_status: :preview_card)

  root date_detection: false do
    field(:id, type: 'long')
    field(:account_id, type: 'long')
    field(:text, type: 'text', analyzer: 'verbatim', value: ->(status) { status.searchable_text }) { field(:stemmed, type: 'text', analyzer: 'content'); field(:japanese, type: 'text', analyzer: 'japanese_content') }
    field(:tags, type: 'text', analyzer: 'hashtag', value: ->(status) { status.tags.map(&:display_name) })
    field(:language, type: 'keyword')
    field(:properties, type: 'keyword', value: ->(status) { status.searchable_properties })
    field(:created_at, type: 'date', value: ->(status) { clamp_date(status.created_at) })
  end
end
