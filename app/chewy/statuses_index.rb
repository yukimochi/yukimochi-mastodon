# frozen_string_literal: true

class StatusesIndex < Chewy::Index
  settings index: { refresh_interval: '15m' }, analysis: {
    filter: {
      english_stemmer: {
        type: 'stemmer',
        language: 'english',
      },
      english_possessive_stemmer: {
        type: 'stemmer',
        language: 'possessive_english',
      },
    },
    tokenizer: {
      ja_tokenizer: {
        type: 'kuromoji_tokenizer',
        mode: 'search'
      },
    },
    analyzer: {
      content: {
        tokenizer: 'ja_tokenizer',
        type: 'custom',
        char_filter: %w(
          icu_normalizer
        ),
        filter: %w(
          kuromoji_stemmer
          kuromoji_part_of_speech
          english_possessive_stemmer
          english_stemmer
        ),
      },
      ja_default_analyzer: {
        tokenizer: 'kuromoji_tokenizer',
      },
    },
  }

  define_type ::Status.unscoped.kept.without_reblogs.includes(:media_attachments), delete_if: ->(status) { status.searchable_by.empty? } do
    crutch :mentions do |collection|
      data = ::Mention.where(status_id: collection.map(&:id)).where(account: Account.local).pluck(:status_id, :account_id)
      data.each.with_object({}) { |(id, name), result| (result[id] ||= []).push(name) }
    end

    crutch :favourites do |collection|
      data = ::Favourite.where(status_id: collection.map(&:id)).where(account: Account.local).pluck(:status_id, :account_id)
      data.each.with_object({}) { |(id, name), result| (result[id] ||= []).push(name) }
    end

    crutch :reblogs do |collection|
      data = ::Status.where(reblog_of_id: collection.map(&:id)).where(account: Account.local).pluck(:reblog_of_id, :account_id)
      data.each.with_object({}) { |(id, name), result| (result[id] ||= []).push(name) }
    end

    crutch :bookmarks do |collection|
      data = ::Bookmark.where(status_id: collection.map(&:id)).where(account: Account.local).pluck(:status_id, :account_id)
      data.each.with_object({}) { |(id, name), result| (result[id] ||= []).push(name) }
    end

    root date_detection: false do
      field :id, type: 'long'
      field :account_id, type: 'long'

      field :text, type: 'text', analyzer: 'ja_default_analyzer', value: ->(status) { [status.spoiler_text, Formatter.instance.plaintext(status)].concat(status.media_attachments.map(&:description)).concat(status.preloadable_poll ? status.preloadable_poll.options : []).join("\n\n") } do
        field :stemmed, type: 'text', analyzer: 'content'
      end

      field :searchable_by, type: 'long', value: ->(status, crutches) { status.searchable_by(crutches) }
    end
  end
end
