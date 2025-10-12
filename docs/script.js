(function () {
    const navToggle = document.querySelector('.nav-toggle');
    const primaryNav = document.getElementById('primary-nav');
    const faqButtons = document.querySelectorAll('.faq-item button');

    if (navToggle && primaryNav) {
        navToggle.addEventListener('click', function () {
            const expanded = navToggle.getAttribute('aria-expanded') === 'true';
            navToggle.setAttribute('aria-expanded', String(!expanded));
            primaryNav.setAttribute('aria-expanded', String(!expanded));
        });
    }

    if (faqButtons.length) {
        faqButtons.forEach(function (button) {
            button.addEventListener('click', function () {
                const parent = button.closest('.faq-item');
                const expanded = button.getAttribute('aria-expanded') === 'true';
                button.setAttribute('aria-expanded', String(!expanded));
                if (parent) {
                    parent.toggleAttribute('open', !expanded);
                }
            });
        });
    }

    if ('scrollBehavior' in document.documentElement.style) {
        document.querySelectorAll('a[href^="#"]').forEach(function (link) {
            link.addEventListener('click', function (event) {
                const targetId = link.getAttribute('href').slice(1);
                const target = document.getElementById(targetId);
                if (target) {
                    event.preventDefault();
                    target.scrollIntoView({ behavior: 'smooth' });
                }
            });
        });
    }
})();
