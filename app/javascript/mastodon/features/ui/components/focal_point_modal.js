import React from 'react';
import ImmutablePropTypes from 'react-immutable-proptypes';
import PropTypes from 'prop-types';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';
import classNames from 'classnames';
import { changeUploadCompose } from '../../../actions/compose';
import { getPointerPosition } from '../../video';
import { FormattedMessage, defineMessages, injectIntl } from 'react-intl';
import IconButton from 'mastodon/components/icon_button';
import Button from 'mastodon/components/button';
import Video from 'mastodon/features/video';

const messages = defineMessages({
  close: { id: 'lightbox.close', defaultMessage: 'Close' },
  apply: { id: 'upload_modal.apply', defaultMessage: 'Apply' },
  placeholder: { id: 'upload_modal.description_placeholder', defaultMessage: 'A quick brown fox jumps over the lazy dog' },
});

const mapStateToProps = (state, { id }) => ({
  media: state.getIn(['compose', 'media_attachments']).find(item => item.get('id') === id),
});

const mapDispatchToProps = (dispatch, { id }) => ({

  onSave: (description, x, y) => {
    dispatch(changeUploadCompose(id, { description, focus: `${x.toFixed(2)},${y.toFixed(2)}` }));
  },

});

export default @connect(mapStateToProps, mapDispatchToProps)
@injectIntl
class FocalPointModal extends ImmutablePureComponent {

  static propTypes = {
    media: ImmutablePropTypes.map.isRequired,
    onClose: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  state = {
    x: 0,
    y: 0,
    focusX: 0,
    focusY: 0,
    dragging: false,
    description: '',
    dirty: false,
  };

  componentWillMount () {
    this.updatePositionFromMedia(this.props.media);
  }

  componentWillReceiveProps (nextProps) {
    if (this.props.media.get('id') !== nextProps.media.get('id')) {
      this.updatePositionFromMedia(nextProps.media);
    }
  }

  componentWillUnmount () {
    document.removeEventListener('mousemove', this.handleMouseMove);
    document.removeEventListener('mouseup', this.handleMouseUp);
  }

  handleMouseDown = e => {
    document.addEventListener('mousemove', this.handleMouseMove);
    document.addEventListener('mouseup', this.handleMouseUp);

    this.updatePosition(e);
    this.setState({ dragging: true });
  }

  handleMouseMove = e => {
    this.updatePosition(e);
  }

  handleMouseUp = () => {
    document.removeEventListener('mousemove', this.handleMouseMove);
    document.removeEventListener('mouseup', this.handleMouseUp);

    this.setState({ dragging: false });
  }

  updatePosition = e => {
    const { x, y } = getPointerPosition(this.node, e);
    const focusX   = (x - .5) *  2;
    const focusY   = (y - .5) * -2;

    this.setState({ x, y, focusX, focusY, dirty: true });
  }

  updatePositionFromMedia = media => {
    const focusX      = media.getIn(['meta', 'focus', 'x']);
    const focusY      = media.getIn(['meta', 'focus', 'y']);
    const description = media.get('description') || '';

    if (focusX && focusY) {
      const x = (focusX /  2) + .5;
      const y = (focusY / -2) + .5;

      this.setState({
        x,
        y,
        focusX,
        focusY,
        description,
        dirty: false,
      });
    } else {
      this.setState({
        x: 0.5,
        y: 0.5,
        focusX: 0,
        focusY: 0,
        description,
        dirty: false,
      });
    }
  }

  handleChange = e => {
    this.setState({ description: e.target.value, dirty: true });
  }

  handleSubmit = () => {
    this.props.onSave(this.state.description, this.state.focusX, this.state.focusY);
    this.props.onClose();
  }

  setRef = c => {
    this.node = c;
  }

  render () {
    const { media, intl, onClose } = this.props;
    const { x, y, dragging, description, dirty } = this.state;

    const width  = media.getIn(['meta', 'original', 'width']) || null;
    const height = media.getIn(['meta', 'original', 'height']) || null;
    const focals = ['image', 'gifv'].includes(media.get('type'));

    const previewRatio  = 16/9;
    const previewWidth  = 200;
    const previewHeight = previewWidth / previewRatio;

    return (
      <div className='modal-root__modal report-modal' style={{ maxWidth: 960 }}>
        <div className='report-modal__target'>
          <IconButton className='media-modal__close' title={intl.formatMessage(messages.close)} icon='times' onClick={onClose} size={16} />
          <FormattedMessage id='upload_modal.edit_media' defaultMessage='Edit media' />
        </div>

        <div className='report-modal__container'>
          <div className='report-modal__comment'>
            {focals && <p><FormattedMessage id='upload_modal.hint' defaultMessage='Click or drag the circle on the preview to choose the focal point which will always be in view on all thumbnails.' /></p>}

            <label className='setting-text-label' htmlFor='upload-modal__description'><FormattedMessage id='upload_form.description' defaultMessage='Describe for the visually impaired' /></label>

            <textarea
              id='upload-modal__description'
              className='setting-text light'
              value={description}
              onChange={this.handleChange}
              autoFocus
            />

            <Button disabled={!dirty} text={intl.formatMessage(messages.apply)} onClick={this.handleSubmit} />
          </div>

          <div className='report-modal__statuses'>
            {focals && (
              <div className={classNames('focal-point', { dragging })} ref={this.setRef}>
                {media.get('type') === 'image' && <img src={media.get('url')} width={width} height={height} alt='' />}
                {media.get('type') === 'gifv' && <video src={media.get('url')} width={width} height={height} loop muted autoPlay />}

                <div className='focal-point__preview'>
                  <strong><FormattedMessage id='upload_modal.preview_label' defaultMessage='Preview ({ratio})' values={{ ratio: '16:9' }} /></strong>
                  <div style={{ width: previewWidth, height: previewHeight, backgroundImage: `url(${media.get('preview_url')})`, backgroundSize: 'cover', backgroundPosition: `${x * 100}% ${y * 100}%` }} />
                </div>

                <div className='focal-point__reticle' style={{ top: `${y * 100}%`, left: `${x * 100}%` }} />
                <div className='focal-point__overlay' onMouseDown={this.handleMouseDown} />
              </div>
            )}

            {['audio', 'video'].includes(media.get('type')) && (
              <Video
                preview={media.get('preview_url')}
                blurhash={media.get('blurhash')}
                src={media.get('url')}
                detailed
                editable
              />
            )}
          </div>
        </div>
      </div>
    );
  }

}
