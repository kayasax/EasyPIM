(function () {
    function initializeNavToggle() {
        const navToggle = document.querySelector('.nav-toggle');
        const primaryNav = document.getElementById('primary-nav');

        if (navToggle && primaryNav) {
            navToggle.addEventListener('click', function () {
                const expanded = navToggle.getAttribute('aria-expanded') === 'true';
                navToggle.setAttribute('aria-expanded', String(!expanded));
                primaryNav.setAttribute('aria-expanded', String(!expanded));
            });
        }
    }

    function initializeFaqToggles() {
        const faqButtons = document.querySelectorAll('.faq-item button');

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
    }

    function initializeSmoothScroll() {
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
    }

    function initializeHeadingAnchors() {
        const headings = document.querySelectorAll('main h1, main h2');
        const slugCount = Object.create(null);

        headings.forEach(function (heading) {
            if (heading.classList.contains('no-anchor')) {
                return;
            }

            if (heading.closest('[aria-hidden="true"]')) {
                return;
            }

            let id = heading.id;

            if (!id) {
                const baseSlug = heading.textContent
                    .trim()
                    .toLowerCase()
                    .replace(/[^a-z0-9\s-]/g, '')
                    .replace(/\s+/g, '-');

                if (!baseSlug) {
                    return;
                }

                slugCount[baseSlug] = (slugCount[baseSlug] || 0) + 1;
                id = slugCount[baseSlug] === 1 ? baseSlug : baseSlug + '-' + slugCount[baseSlug];
                while (document.getElementById(id)) {
                    slugCount[baseSlug] += 1;
                    id = baseSlug + '-' + slugCount[baseSlug];
                }

                heading.id = id;
            }

            if (!heading.querySelector('.heading-anchor')) {
                const anchor = document.createElement('a');
                anchor.className = 'heading-anchor';
                anchor.href = '#' + id;
                anchor.setAttribute('aria-label', 'Link to ' + heading.textContent.trim());
                anchor.innerHTML = '<span aria-hidden="true">#</span>';
                if (heading.firstChild) {
                    heading.insertBefore(anchor, heading.firstChild);
                } else {
                    heading.appendChild(anchor);
                }
            }
        });
    }

    function init() {
        initializeNavToggle();
        initializeFaqToggles();
        initializeSmoothScroll();
        initializeHeadingAnchors();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
