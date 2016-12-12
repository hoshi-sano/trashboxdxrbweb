require 'dxruby'

# 投げるボール(紙くず)のクラス
class Ball < Sprite
  IMAGE = Image.load('./images/ball.png')
  X_ACCELERATION = 0.9
  Y_ACCELERATION = 1

  def initialize(power, cursor, trash_box)
    # キャラクターの右上が初期位置
    chara = cursor.character
    x = chara.x + chara.image.width
    y = chara.y
    # X方向、Y方向への初期スピード
    # カーソルの位置とゲージのパワーで決まる
    @x_speed = (cursor.x / 10) * power + 1
    @y_speed = (-(Window.height - cursor.y) / 10) * power
    super(x, y, IMAGE)
    @trash_box = trash_box
  end

  def update
    self.x += @x_speed
    self.y += @y_speed
    # X方向のスピードは徐々に減衰する(最低値が1)
    # Y方向へは徐々に加速する
    @x_speed = @x_speed * X_ACCELERATION + 1
    @y_speed = @y_speed + X_ACCELERATION
    miss if self.x > Window.width || self.y > Window.height
  end

  def shot
    vanish
  end

  def miss
    @trash_box.combo_break
    vanish
  end
end

# 射出方向を決めるカーソルのクラス
# 円の軌道上を移動する
class Cursor < Sprite
  # 円の半径
  RADIUS = 100
  IMAGE = Image.load('./images/cursor.png')

  attr_reader :character

  def initialize(character)
    @character = character
    # キャラクターの右上が円の中心座標
    @center_x = @character.x + @character.image.width
    @center_y = @character.y
    super(@center_x, @center_y, IMAGE)
    # 角度(0から90度の範囲、初期値75)
    @theta = 75
    calc_xy(1)
  end

  # カーソルの位置を計算する
  # inputには-1,0,1いずれかの値を期待する
  def calc_xy(input)
    return if input.zero?
    diff = input * 2
    return unless (0..90).include?(@theta - diff)
    @theta -= diff
    radian = @theta * Math::PI / 180
    self.x = @center_x + RADIUS * Math.cos(radian)
    self.y = @center_y - RADIUS * Math.sin(radian)
  end
end

# 射出のパワーを決めるゲージのクラス
class PowerGage < Sprite
  IMAGE = Image.new(200, 20, C_RED)

  def initialize
    super(50, 50, IMAGE)
    self.center_x = 0
    self.visible = false
  end

  def show
    self.visible = true
    self.scale_x = 0
  end

  # 非表示にしつつ、確定したパワーを返す
  def hide
    self.visible = false
    self.scale_x
  end

  # ゲージの増加を表現
  # MAXまで溜まると0に戻る
  def update
    self.scale_x += 0.03
    self.scale_x = 0 if self.scale_x >= 1.1
  end
end

# キャラクターのクラス
class Character < Sprite
  IMAGE = Image.load('./images/character.png')

  def initialize
    super(0, Window.height - IMAGE.height, IMAGE)
  end
end

# ゴミ箱のクラス
# コンボやスコアの計算も兼ねる
class TrashBox < Sprite
  IMAGE = Image.load('./images/trashbox.png')
  RIGHT_EDGE = Window.width - IMAGE.width
  LEFT_EDGE = Window.width - IMAGE.width - 250
  SPEED = 3
  BASE_SCORE = 500

  # 当たり判定用の内部クラス
  class HitBox < Sprite
    IMAGE = Image.new(50, 20)
    def initialize(x, y, parent)
      super(x, y, IMAGE)
      @parent = parent
    end

    def hit
      @parent.hit
    end
  end

  attr_reader :hitbox, :combo, :score, :combo_str, :score_str
  attr_accessor :lv

  def initialize
    super(RIGHT_EDGE, Window.height - IMAGE.height, IMAGE)
    change_direction
    @hitbox = HitBox.new(self.x, self.y, self)
    score_init
    @lv = 1
  end

  def score_init
    @combo = 0
    @score = 0
    @combo_str = ''
    @score_str = ''
  end

  def change_direction
    if (self.x <= LEFT_EDGE)
      @dir = 1
    elsif (self.x >= RIGHT_EDGE)
      @dir = -1
    end
  end

  def update
    return if @lv < 2
    change_direction
    dx = @dir * SPEED
    self.x += dx
    @hitbox.x += dx
  end

  def hit
    @combo += 1
    @score += BASE_SCORE * @combo * @lv
    @combo_str = "COMBO: #{@combo}" if @combo > 1
    @score_str = "SCORE: #{@score}"
  end

  def combo_break
    @combo = 0
    @combo_str = ''
  end
end

chara = Character.new
cursor = Cursor.new(chara)
gage = PowerGage.new
tb = TrashBox.new
balls = []
sprites = [chara, tb, cursor, gage, balls]
update_targets = [balls, gage, tb]

playing = false
font = Font.new(24)
messages = {
  title: 'TRASH BOX',
  lv1:   'Push 1 key: START LEVEL1',
  lv2:   'Push 2 key: START LEVEL2',
  shot:  'Push Z key: THROW TRASH',
  move:  'Push <-/-> key: MOVE CURSOR',
}

Window.loop do
  Window.draw_font(450,  50, tb.score_str, font)
  Window.draw_font(450, 100, tb.combo_str, font)

  # タイトルと操作説明の表示
  unless playing
    Window.draw_font(250, 150, messages[:title], font)
    Window.draw_font(160, 250, messages[:lv1],   font)
    Window.draw_font(160, 300, messages[:lv2],   font)
    Window.draw_font(160, 350, messages[:shot],  font)
    Window.draw_font(140, 400, messages[:move],  font)
    if Input.key_push?(K_1) || Input.key_push?(K_2)
      tb.lv = Input.key_push?(K_1) ? 1 : 2
      tb.score_init
      playing = true
    end
    next
  end

  # ゲームプレイ
  cursor.calc_xy(Input.x)
  if Input.key_push?(K_Z)
    gage.show
  elsif Input.key_release?(K_Z)
    power = gage.hide
    balls << Ball.new(power, cursor, tb)
  end
  Sprite.draw(sprites)
  Sprite.update(update_targets)
  Sprite.check(balls, tb.hitbox)

  # 終了判定
  if balls.size >= 10 && balls.all?(&:vanished?)
    balls.clear
    playing = false
  end
end
